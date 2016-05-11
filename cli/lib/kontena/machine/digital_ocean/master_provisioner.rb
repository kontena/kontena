require 'fileutils'
require 'erb'
require 'open3'
require 'shell-spinner'

module Kontena
  module Machine
    module DigitalOcean
      class MasterProvisioner
        include RandomName
        include Machine::CertHelper

        attr_reader :client, :http_client

        # @param [String] token Digital Ocean token
        def initialize(token)
          @client = DropletKit::Client.new(access_token: token)
        end

        def run!(opts)
          abort('Invalid ssh key') unless File.exists?(File.expand_path(opts[:ssh_key]))

          ssh_key = ssh_key(File.read(File.expand_path(opts[:ssh_key])).strip)
          abort('Ssh key does not exist in Digital Ocean') unless ssh_key

          if opts[:ssl_cert]
            abort('Invalid ssl cert') unless File.exists?(File.expand_path(opts[:ssl_cert]))
            ssl_cert = File.read(File.expand_path(opts[:ssl_cert]))
          else
            ShellSpinner "Generating self-signed SSL certificate" do
              ssl_cert = generate_self_signed_cert
            end
          end

          userdata_vars = {
              ssl_cert: ssl_cert,
              auth_server: opts[:auth_server],
              version: opts[:version],
              vault_secret: opts[:vault_secret],
              vault_iv: opts[:vault_iv],
              mongodb_uri: opts[:mongodb_uri]
          }

          droplet = DropletKit::Droplet.new(
              name: generate_name,
              region: opts[:region],
              image: 'coreos-stable',
              size: opts[:size],
              private_networking: true,
              user_data: user_data(userdata_vars),
              ssh_keys: [ssh_key.id]
          )

          ShellSpinner "Creating DigitalOcean droplet #{droplet.name.colorize(:cyan)} " do
            droplet = client.droplets.create(droplet)
            until droplet.status == 'active'
              droplet = client.droplets.find(id: droplet.id)
              sleep 5
            end
          end

          master_url = "https://#{droplet.public_ip}"
          Excon.defaults[:ssl_verify_peer] = false
          @http_client = Excon.new("#{master_url}", :connect_timeout => 10)

          ShellSpinner "Waiting for #{droplet.name.colorize(:cyan)} to start" do
            sleep 5 until master_running?
          end

          puts "Kontena Master is now running at #{master_url}"
          puts "Use #{"kontena login --name=#{droplet.name.sub('kontena-master-', '')} #{master_url}".colorize(:light_black)} to complete Kontena Master setup"
        end

        def user_data(vars)
          cloudinit_template = File.join(__dir__ , '/cloudinit_master.yml')
          erb(File.read(cloudinit_template), vars)
        end

        def generate_name
          "kontena-master-#{super}-#{rand(1..9)}"
        end

        def ssh_key(public_key)
          client.ssh_keys.all.find{|key| key.public_key == public_key}
        end

        def master_running?
          http_client.get(path: '/').status == 200
        rescue
          false
        end

        def erb(template, vars)
          ERB.new(template, nil, '%<>-').result(OpenStruct.new(vars).instance_eval { binding })
        end
      end
    end
  end
end

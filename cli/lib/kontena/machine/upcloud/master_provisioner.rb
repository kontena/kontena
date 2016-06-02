require 'fileutils'
require 'erb'
require 'open3'
require 'shell-spinner'

module Kontena
  module Machine
    module Upcloud
      class MasterProvisioner
        include RandomName
        include Machine::CertHelper
        include UpcloudCommon

        attr_reader :http_client, :username, :password

        # @param [String] token Upcloud token
        def initialize(upcloud_username, upcloud_password)
          @username = upcloud_username
          @password = upcloud_password
        end

        def run!(opts)
          if File.readable?(File.expand_path(opts[:ssh_key]))
            ssh_key = File.read(File.expand_path(opts[:ssh_key])).strip
          end

          abort('Invalid ssh key') unless ssh_key && ssh_key.start_with?('ssh-')

          if opts[:ssl_cert]
            abort('Invalid ssl cert') unless File.exists?(File.expand_path(opts[:ssl_cert]))
            ssl_cert = File.read(File.expand_path(opts[:ssl_cert]))
          else
            ShellSpinner "Generating self-signed SSL certificate" do
              ssl_cert = generate_self_signed_cert
            end
          end

          abort_unless_api_access

          abort('CoreOS template not found on Upcloud') unless coreos_template = find_template('CoreOS Stable')
          abort('Server plan not found on Upcloud') unless plan = find_plan(opts[:plan])
          abort('Zone not found on Upcloud') unless zone_exist?(opts[:zone])

          hostname = generate_name

          userdata_vars = {
              ssl_cert: ssl_cert,
              auth_server: opts[:auth_server],
              version: opts[:version],
              vault_secret: opts[:vault_secret],
              vault_iv: opts[:vault_iv],
              mongodb_uri: opts[:mongodb_uri]
          }

          device_data = {
            server: {
              zone: opts[:zone],
              title: "Kontena Master #{hostname}",
              hostname: hostname,
              plan: plan[:name],
              vnc: 'off',
              timezone: 'UTC',
              user_data: user_data(userdata_vars),
              firewall: 'off',
              storage_devices: {
                storage_device: [
                  {
                    action: 'clone',
                    storage: coreos_template[:uuid],
                    title: "From template #{coreos_template[:title]}",
                    size: plan[:storage_size],
                    tier: 'maxiops'
                  }
                ]
              },
              login_user: {
                create_password: 'no',
                username: 'root',
                ssh_keys: {
                  ssh_key: [ssh_key]
                }
              }
            }
          }.to_json

          ShellSpinner "Creating Upcloud master #{hostname.colorize(:cyan)} " do
            response = post('server', body: device_data)
            if response.has_key?(:error)
              abort("\nUpcloud server creation failed (#{response[:error].fetch(:error_message, '')})")
            end
            device_data = response[:server]

            until device_data && device_data.fetch(:state, nil).to_s == 'maintenance'
              device_data = get("server/#{device[:uuid]}").fetch(:server, {}) rescue nil
              sleep 5
            end
          end

          device_public_ip = device_data[:ip_addresses][:ip_address].find do |ip|
            ip[:access].eql?('public') && ip[:family].eql?('IPv4')
          end

          abort('Server public ip not found, destroy manually.') unless device_public_ip

          master_url = "https://#{device_public_ip[:address]}"
          Excon.defaults[:ssl_verify_peer] = false
          @http_client = Excon.new("#{master_url}", :connect_timeout => 10)

          ShellSpinner "Waiting for #{hostname.colorize(:cyan)} to start" do
            sleep 5 until master_running?
          end

          puts "Kontena Master is now running at #{master_url}"
          puts "Use #{"kontena login --name=#{hostname.sub('kontena-master-', '')} #{master_url}".colorize(:light_black)} to complete Kontena Master setup"
        end

        def user_data(vars)
          cloudinit_template = File.join(__dir__ , '/cloudinit_master.yml')
          erb(File.read(cloudinit_template), vars)
        end

        def generate_name
          "kontena-master-#{super}-#{rand(1..9)}"
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

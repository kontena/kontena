require 'fileutils'
require 'erb'
require 'open3'
require 'shell-spinner'

module Kontena
  module Machine
    module DigitalOcean
      class NodeProvisioner
        include RandomName

        attr_reader :client, :api_client

        # @param [Kontena::Client] api_client Kontena api client
        # @param [String] token Digital Ocean token
        def initialize(api_client, token)
          @api_client = api_client
          @client = DropletKit::Client.new(access_token: token)
        end

        def run!(opts)
          abort('Invalid ssh key') unless File.exists?(File.expand_path(opts[:ssh_key]))

          ssh_key = ssh_key(File.read(File.expand_path(opts[:ssh_key])).strip)
          abort('Ssh key does not exist in Digital Ocean') unless ssh_key

          userdata_vars = {
            version: opts[:version],
            master_uri: opts[:master_uri],
            grid_token: opts[:grid_token],
          }

          droplet = DropletKit::Droplet.new(
            name: opts[:name] || generate_name,
            region: opts[:region],
            image: 'coreos-stable',
            size: opts[:size],
            private_networking: true,
            user_data: user_data(userdata_vars),
            ssh_keys: [ssh_key.id]
          )
          created = client.droplets.create(droplet)
          ShellSpinner "Creating DigitalOcean droplet #{droplet.name.colorize(:cyan)} " do
            sleep 5 until client.droplets.find(id: created.id).status == 'active'
          end
          node = nil
          ShellSpinner "Waiting for node #{droplet.name.colorize(:cyan)} join to grid #{opts[:grid].colorize(:cyan)} " do
            sleep 2 until node = droplet_exists_in_grid?(opts[:grid], droplet)
          end
          set_labels(
            node,
            [
              "region=#{opts[:region]}",
              "az=#{opts[:region]}",
              "provider=digitalocean"
            ]
          )
        end

        def user_data(vars)
          cloudinit_template = File.join(__dir__ , '/cloudinit.yml')
          erb(File.read(cloudinit_template), vars)
        end

        def generate_name
          "#{super}-#{rand(1..99)}"
        end

        def ssh_key(public_key)
          ssh_key = client.ssh_keys.all.find{|key| key.public_key == public_key}
        end

        def droplet_exists_in_grid?(grid, droplet)
          api_client.get("grids/#{grid}/nodes")['nodes'].find{|n| n['name'] == droplet.name}
        end

        def erb(template, vars)
          ERB.new(template).result(OpenStruct.new(vars).instance_eval { binding })
        end

        def set_labels(node, labels)
          data = {labels: labels}
          api_client.put("nodes/#{node['id']}", data, {}, {'Kontena-Grid-Token' => node['grid']['token']})
        end
      end
    end
  end
end

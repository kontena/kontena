require 'fileutils'
require 'erb'
require 'open3'
require 'shell-spinner'

module Kontena
  module Machine
    module Upcloud
      class NodeProvisioner
        include RandomName
        include UpcloudCommon

        attr_reader :api_client, :username, :password

        # @param [Kontena::Client] api_client Kontena api client
        # @param [String] upcloud_username Upcloud username
        # @param [String] upcloud_password Upcloud password
        def initialize(api_client, upcloud_username, upcloud_password)
          @api_client = api_client
          @username = upcloud_username
          @password = upcloud_password
        end

        def run!(opts)
          if File.readable?(File.expand_path(opts[:ssh_key]))
            ssh_key = File.read(File.expand_path(opts[:ssh_key])).strip
          end

          abort('Invalid ssh key') unless ssh_key && ssh_key.start_with?('ssh-')

          userdata_vars = {
            version: opts[:version],
            master_uri: opts[:master_uri],
            grid_token: opts[:grid_token],
          }

          abort_unless_api_access
          
          abort('CoreOS template not found on Upcloud') unless coreos_template = find_template('CoreOS Stable')
          abort('Server plan not found on Upcloud') unless plan = find_plan(opts[:plan])
          abort('Zone not found on Upcloud') unless zone_exist?(opts[:zone])

          hostname = generate_name

          device_data = {
            server: {
              zone: opts[:zone],
              title: "Kontena Grid #{opts[:grid]} Node #{hostname}",
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

          ShellSpinner "Creating Upcloud node #{hostname.colorize(:cyan)} " do
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

          node = nil
          ShellSpinner "Waiting for node #{hostname.colorize(:cyan)} join to grid #{opts[:grid].colorize(:cyan)} " do
            sleep 2 until node = node_exists_in_grid?(opts[:grid], hostname)
          end
          set_labels(node, ["region=#{opts[:zone]}", "provider=upcloud"])
        end

        def user_data(vars)
          cloudinit_template = File.join(__dir__ , '/cloudinit.yml')
          erb(File.read(cloudinit_template), vars)
        end

        def generate_name
          "#{super}-#{rand(1..99)}"
        end

        def node_exists_in_grid?(grid, hostname)
          api_client.get("grids/#{grid}/nodes")['nodes'].find{|n| n['name'] == hostname}
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

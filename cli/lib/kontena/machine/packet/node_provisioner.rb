require 'shell-spinner'

module Kontena
  module Machine
    module Packet
      class NodeProvisioner
        include RandomName
        include PacketCommon

        attr_reader :client, :api_client

        # @param [Kontena::Client] api_client Kontena api client
        # @param [String] token Digital Ocean token
        def initialize(api_client, token)
          @api_client = api_client
          @client = login(token)
        end

        def run!(opts)
          abort('Project does not exist in Packet') unless project = find_project(opts[:project])
          abort('Facility does not exist in Packet') unless facility = find_facility(opts[:facility])
          abort('Operating system coreos_stable does not exist in Packet') unless os = find_os('coreos_stable')
          abort('Device type does not exist in Packet') unless plan = find_plan(opts[:plan])

          check_or_create_ssh_key(opts[:ssh_key]) if opts[:ssh_key]

          userdata_vars = {
            version: opts[:version],
            master_uri: opts[:master_uri],
            grid_token: opts[:grid_token],
          }

          device = project.new_device(
            hostname: generate_name,
            facility: facility.to_hash,
            operating_system: os.to_hash,
            plan: plan.to_hash,
            billing_cycle: opts[:billing],
            locked: false,
            userdata: user_data(userdata_vars, 'cloudinit.yml')
          )

          ShellSpinner "Creating Packet device #{device.hostname.colorize(:cyan)} " do
            api_retry "Packet API reported an error, please try again" do
              response = client.create_device(device)
              raise response.body unless response.success?
            end

            until device && [:active, :provisioning, :powering_on].include?(device.state)
              device = find_device(project.id, device.hostname) rescue nil
              sleep 5
            end
          end

          node = nil
          ShellSpinner "Waiting for node #{device.hostname.colorize(:cyan)} join to grid #{opts[:grid].colorize(:cyan)} (estimate 4 minutes) " do
            sleep 2 until node = device_exists_in_grid?(opts[:grid], device)
          end
          set_labels(node, ["region=#{opts[:facility]}", "provider=packet"])
        end

        def generate_name
          "#{super}-#{rand(1..99)}"
        end

        def device_exists_in_grid?(grid, device)
          api_client.get("grids/#{grid}/nodes")['nodes'].find{|n| n['name'] == device.hostname}
        end

        def set_labels(node, labels)
          data = {labels: labels}
          api_client.put("nodes/#{node['id']}", data, {}, {'Kontena-Grid-Token' => node['grid']['token']})
        end
      end
    end
  end
end

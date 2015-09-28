require 'fileutils'
require 'erb'
require 'open3'
require 'base64'
require 'shell-spinner'

module Kontena
  module Machine
    module Azure
      class NodeProvisioner
        include RandomName

        attr_reader :client, :api_client

        # @param [Kontena::Client] api_client Kontena api client
        # @param [String] subscription_id Azure subscription id
        # @param [String] certificate Path to Azure management certificate
        def initialize(api_client, subscription_id, certificate)
          @api_client = api_client
          abort('Invalid management certificate') unless File.exists?(File.expand_path(certificate))

          @client = ::Azure
          client.management_certificate = certificate
          client.subscription_id        = subscription_id
          client.vm_management.initialize_external_logger(Logger.new) # We don't want all the output
        end

        def run!(opts)
          abort('Invalid ssh key') unless File.exists?(File.expand_path(opts[:ssh_key]))
          node = nil
          vm_name = opts[:name] || generate_name
          cloud_service_name = generate_cloud_service_name(vm_name, opts[:grid])

          ShellSpinner "Creating Azure Virtual Machine #{vm_name.colorize(:cyan)}" do
            if opts[:virtual_network].nil?
              location = opts[:location].downcase.gsub(' ', '-')
              default_network_name = "kontena-#{location}"
              create_virtual_network(default_network_name, opts[:location]) unless virtual_network_exist?(default_network_name)
              opts[:virtual_network] = default_network_name
              opts[:subnet] = 'subnet-1'
            end

            userdata_vars = {
              version: opts[:version],
              master_uri: opts[:master_uri],
              grid_token: opts[:grid_token],
            }

            params = {
              vm_name: vm_name,
              vm_user: 'core',
              location: opts[:location],
              image: '2b171e93f07c4903bcad35bda10acf22__CoreOS-Stable-766.3.0',
              custom_data: Base64.encode64(user_data(userdata_vars)),
              ssh_key: opts[:ssh_key]
            }
            options = {
              cloud_service_name: cloud_service_name,
              deployment_name: vm_name,
              virtual_network_name: opts[:virtual_network],
              subnet_name: opts[:subnet],
              tcp_endpoints: '80',
              private_key_file: opts[:ssh_key],
              ssh_port: 22,
              vm_size: opts[:size],
            }


            client.vm_management.create_virtual_machine(params,options)
          end
          ShellSpinner "Waiting for node #{vm_name.colorize(:cyan)} join to grid #{opts[:grid].colorize(:cyan)} " do
            sleep 2 until node = vm_exists_in_grid?(opts[:grid], vm_name)
          end
          if node
            labels = ["region=#{cloud_service(cloud_service_name).location}"]
            set_labels(node, labels)
          end
        end

        def user_data(vars)
          cloudinit_template = File.join(__dir__ , '/cloudinit.yml')
          erb(File.read(cloudinit_template), vars)
        end

        def generate_name
          "#{super}-#{rand(1..99)}"
        end

        def generate_cloud_service_name(name, grid)
          "kontena-#{grid}-#{name}"
        end

        def vm_exists_in_grid?(grid, name)
          api_client.get("grids/#{grid}/nodes")['nodes'].find{|n| n['name'] == name}
        end

        def erb(template, vars)
          ERB.new(template).result(OpenStruct.new(vars).instance_eval { binding })
        end

        def cloud_service_exist?(name)
          cloud_service(name)
        end

        def cloud_service(name)
          client.cloud_service_management.get_cloud_service(name)
        end

        def virtual_network_exist?(name)
          client.network_management.list_virtual_networks.find{|n| n.name == name}
        end

        def create_virtual_network(name, location)
          address_space = ['10.0.0.0/20']
          options = {subnet: [{:name => 'subnet-1',  :ip_address=>'10.0.0.0',  :cidr=>23}]}
          client.network_management.set_network_configuration(name, location, address_space, options)
        end

        def set_labels(node, labels)
          data = {}
          data[:labels] = labels
          api_client.put("nodes/#{node['id']}", data, {}, {'Kontena-Grid-Token' => node['grid']['token']})
        end
      end

    end
  end
end

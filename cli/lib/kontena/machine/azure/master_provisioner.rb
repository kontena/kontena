require 'fileutils'
require 'erb'
require 'open3'
require 'shell-spinner'
require_relative '../../../../lib/kontena/cli/login_command'

module Kontena
  module Machine
    module Azure
      class MasterProvisioner
        include RandomName

        attr_reader :client

        # @param [String] subscription_id Azure subscription id
        # @param [String] certificate Path to Azure management certificate
        def initialize(subscription_id, certificate)

          abort('Invalid management certificate') unless File.exists?(File.expand_path(certificate))

          @client = ::Azure
          client.management_certificate = certificate
          client.subscription_id        = subscription_id
          client.vm_management.initialize_external_logger(Logger.new) # We don't want all the output
        end

        def run!(opts)
          abort('Invalid ssh key') unless File.exists?(File.expand_path(opts[:ssh_key]))
          vm_name = 'kontena-master'
          cloud_service_name = generate_cloud_service_name
          virtual_machine = nil
          ShellSpinner "Creating Azure Virtual Machine #{vm_name.colorize(:cyan)}" do
            if opts[:virtual_network].nil?
              location = opts[:location].downcase.gsub(' ', '-')
              default_network_name = "kontena-#{location}"
              create_virtual_network(default_network_name, opts[:location]) unless virtual_network_exist?(default_network_name)
              opts[:virtual_network] = default_network_name
              opts[:subnet] = 'subnet-1'
            end

            userdata_vars = {
                version: opts[:version]
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
                tcp_endpoints: '80,8080,443,8443',
                private_key_file: opts[:ssh_key],
                ssh_port: 22,
                vm_size: opts[:size],
            }


            virtual_machine =  client.vm_management.create_virtual_machine(params,options)
          end

          puts "Kontena Master is now running at #{(virtual_machine.ipaddress+':8080').colorize(:green)}"
          login_command = Kontena::Cli::LoginCommand.new('')
          login_command.run(["#{virtual_machine.ipaddress}:8080"])
        end

        def erb(template, vars)
          ERB.new(template).result(OpenStruct.new(vars).instance_eval { binding })
        end

        def user_data(vars)
          cloudinit_template = File.join(__dir__ , '/cloudinit_master.yml')
          erb(File.read(cloudinit_template), vars)
        end


        def generate_cloud_service_name
          "kontena-master-#{generate_name}-#{rand(1..99)}"
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
      end
    end
  end
end

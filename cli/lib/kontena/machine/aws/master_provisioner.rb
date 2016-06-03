require 'fileutils'
require 'erb'
require 'open3'
require 'shell-spinner'
require_relative 'common'

module Kontena
  module Machine
    module Aws
      class MasterProvisioner
        include RandomName
        include Common
        include Machine::CertHelper
        attr_reader :ec2, :http_client, :region

        # @param [String] access_key_id aws_access_key_id
        # @param [String] secret_key aws_secret_access_key
        # @param [String] region
        def initialize(access_key_id, secret_key, region)
          @ec2 = ::Aws::EC2::Resource.new(
            region: region, credentials: ::Aws::Credentials.new(access_key_id, secret_key)
          )
        end

        # @param [Hash] opts
        def run!(opts)
          ssl_cert = nil
          if opts[:ssl_cert]
            abort('Invalid ssl cert') unless File.exists?(File.expand_path(opts[:ssl_cert]))
            ssl_cert = File.read(File.expand_path(opts[:ssl_cert]))
          else
            ShellSpinner "Generating self-signed SSL certificate" do
              ssl_cert = generate_self_signed_cert
            end
          end

          ami = resolve_ami(region)
          abort('No valid AMI found for region') unless ami
          opts[:vpc] = default_vpc.vpc_id unless opts[:vpc]
          if opts[:subnet].nil?
            subnet = default_subnet(opts[:vpc], region+opts[:zone])
          else
            subnet = ec2.subnet(opts[:subnet])
          end
          abort('Failed to find subnet!') unless subnet
          userdata_vars = {
              ssl_cert: ssl_cert,
              auth_server: opts[:auth_server],
              version: opts[:version],
              vault_secret: opts[:vault_secret],
              vault_iv: opts[:vault_iv],
              mongodb_uri: opts[:mongodb_uri]
          }

          security_groups = opts[:security_groups] ? 
              resolve_security_groups_to_ids(opts[:security_groups], opts[:vpc]) : 
              ensure_security_group(opts[:vpc])

          name = generate_name
          ec2_instance = ec2.create_instances({
            image_id: ami,
            min_count: 1,
            max_count: 1,
            instance_type: opts[:type],
            key_name: opts[:key_pair],
            user_data: Base64.encode64(user_data(userdata_vars)),
            block_device_mappings: [
              {
                device_name: '/dev/xvda',
                virtual_name: 'Root',
                ebs: {
                  volume_size: opts[:storage],
                  volume_type: 'gp2'
                }
              }
            ],
            network_interfaces: [
             {
               device_index: 0,
               subnet_id: subnet.subnet_id,
               groups: security_groups,
               associate_public_ip_address: opts[:associate_public_ip],
               delete_on_termination: true
             }
            ]
          }).first

          add_tags(opts[:tags], ec2_instance, name)
          
          ShellSpinner "Creating AWS instance #{name.colorize(:cyan)} " do
            sleep 5 until ec2_instance.reload.state.name == 'running'
          end
          public_ip = ec2_instance.reload.public_ip_address
          if public_ip.nil?
            master_url = "https://#{ec2_instance.private_ip_address}"
            puts "Could not get public IP for the created master, private connect url is: #{master_url}"
          else
            master_url = "https://#{ec2_instance.public_ip_address}"
            Excon.defaults[:ssl_verify_peer] = false
            http_client = Excon.new(master_url, :connect_timeout => 10)
            ShellSpinner "Waiting for #{name.colorize(:cyan)} to start " do
              sleep 5 until master_running?(http_client)
            end
          end
          
          puts "Kontena Master is now running at #{master_url}"
          puts "Use #{"kontena login --name=#{name.sub('kontena-master-', '')} #{master_url}".colorize(:light_black)} to complete Kontena Master setup"
        end

        ##
        # @param [String] vpc_id
        # @return [Array] Security group id in array
        def ensure_security_group(vpc_id)
          group_name = "kontena_master"
          group_id = resolve_security_groups_to_ids(group_name, vpc_id)
          
          if group_id.empty?
            ShellSpinner "Creating AWS security group" do
              sg = create_security_group(group_name, vpc_id)
              group_id = [sg.group_id]
            end
          end
          group_id
        end

        ##
        # creates security_group and authorizes default port ranges
        #
        # @param [String] name
        # @param [String, NilClass] vpc_id
        # @return Aws::EC2::SecurityGroup
        def create_security_group(name, vpc_id = nil)
          sg = ec2.create_security_group({
            group_name: name,
            description: "Kontena Master",
            vpc_id: vpc_id
          })

          sg.authorize_ingress({
            ip_protocol: 'tcp',
            from_port: 443,
            to_port: 443,
            cidr_ip: '0.0.0.0/0'
          })

          sg.authorize_ingress({
            ip_protocol: 'tcp',
            from_port: 22,
            to_port: 22,
            cidr_ip: '0.0.0.0/0'
          })

          sg
        end

        # @return [String]
        def region
          ec2.client.config.region
        end

        def user_data(vars)
          cloudinit_template = File.join(__dir__ , '/cloudinit_master.yml')
          erb(File.read(cloudinit_template), vars)
        end

        def generate_name
          "kontena-master-#{super}-#{rand(1..9)}"
        end

        def master_running?(http_client)
          http_client.get(path: '/').status == 200
        rescue
          false
        end

        def erb(template, vars)
          ERB.new(template, nil, '%<>-').result(
            OpenStruct.new(vars).instance_eval { binding }
          )
        end
      end
    end
  end
end

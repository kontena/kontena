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
        attr_reader :client, :http_client, :region

        # @param [String] access_key_id aws_access_key_id
        # @param [String] secret_key aws_secret_access_key
        # @param [String] region
        def initialize(access_key_id, secret_key, region)
          @client = Fog::Compute.new(
            :provider => 'AWS',
            :aws_access_key_id => access_key_id,
            :aws_secret_access_key => secret_key,
            :region => region
          )
        end

        # @param [Hash] opts
        def run!(opts)
          if opts[:ssl_cert]
            abort('Invalid ssl cert') unless File.exists?(File.expand_path(opts[:ssl_cert]))
            ssl_cert = File.read(File.expand_path(opts[:ssl_cert]))
          end

          ami = resolve_ami(client.region)
          abort('No valid AMI found for region') unless ami
          opts[:vpc] = default_vpc.id unless opts[:vpc]
          if opts[:subnet].nil?
            subnet = default_subnet(opts[:vpc], client.region+opts[:zone])
            opts[:subnet] = subnet.subnet_id
          else
            subnet = client.subnets.get(opts[:subnet])
          end
          userdata_vars = {
              ssl_cert: ssl_cert,
              auth_server: opts[:auth_server],
              version: opts[:version],
              vault_secret: opts[:vault_secret],
              vault_iv: opts[:vault_iv]
          }

          security_group = ensure_security_group(opts[:vpc])
          name = generate_name
          response = client.run_instances(
              ami,
              1,
              1,
              'InstanceType'  => opts[:type],
              'SecurityGroupId' => security_group.group_id,
              'KeyName'       => opts[:key_pair],
              'SubnetId'      => opts[:subnet],
              'UserData'      => user_data(userdata_vars),
              'BlockDeviceMapping' => [
                  {
                      'DeviceName' => '/dev/xvda',
                      'VirtualName' => 'Root',
                      'Ebs.VolumeSize' => opts[:storage],
                      'Ebs.VolumeType' => 'gp2'
                  }
              ]

          )
          instance_id = response.body['instancesSet'].first['instanceId']

          instance = client.servers.get(instance_id)
          ShellSpinner "Creating AWS instance #{name.colorize(:cyan)} " do
            instance.wait_for { ready? }
          end
          if opts[:ssl_cert]
            master_url = "https://#{instance.public_ip_address}"
          else
            master_url = "http://#{instance.public_ip_address}"
          end
          Excon.defaults[:ssl_verify_peer] = false
          @http_client = Excon.new("#{master_url}", :connect_timeout => 10)

          ShellSpinner "Waiting for #{name.colorize(:cyan)} to start" do
            sleep 5 until master_running?
          end

          puts "Kontena Master is now running at #{master_url}"
          puts "Use #{"kontena login #{master_url}".colorize(:light_black)} to complete Kontena Master setup"
        end

        ##
        # @param [String] grid
        # @return Fog::Compute::AWS::SecurityGroup
        def ensure_security_group(vpc_id)
          group_name = "kontena_master"
          if vpc_id
            client.security_groups.all({'group-name' => group_name, 'vpc-id' => vpc_id}).first || create_security_group(group_name, vpc_id)
          else
            client.security_groups.get(group_name) || create_security_group(group_name)
          end
        end

        ##
        # creates security_group and authorizes default port ranges
        #
        # @param [String] name
        # @return Fog::Compute::AWS::SecurityGroup
        def create_security_group(name, vpc_id = nil)
          security_group = client.security_groups.new(:name => name, :description => "Kontena Master", :vpc_id => vpc_id)
          security_group.save

          security_group.authorize_port_range(80..80)
          security_group.authorize_port_range(443..443)
          security_group.authorize_port_range(22..22)
          security_group
        end

        def default_subnet(vpc, zone)
          client.subnets.all('vpc-id' => vpc, 'availabilityZone' => zone).first
        end

        def default_vpc
          client.vpcs.all('isDefault' => true).first
        end

        def user_data(vars)
          cloudinit_template = File.join(__dir__ , '/cloudinit_master.yml')
          erb(File.read(cloudinit_template), vars)
        end

        def generate_name
          "kontena-master-#{super}-#{rand(1..99)}"
        end

        def master_running?
          http_client.get(path: '/').status == 200
        rescue
          false
        end

        def erb(template, vars)
          ERB.new(template).result(OpenStruct.new(vars).instance_eval { binding })
        end
      end
    end
  end
end

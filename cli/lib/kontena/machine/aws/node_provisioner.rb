require 'fileutils'
require 'erb'
require 'open3'
require 'shell-spinner'

module Kontena
  module Machine
    module Aws
      class NodeProvisioner
        include RandomName

        attr_reader :client, :api_client, :region

        # @param [Kontena::Client] api_client Kontena api client
        # @param [String] access_key_id aws_access_key_id
        # @param [String] secret_key aws_secret_access_key
        # @param [String] region
        def initialize(api_client, access_key_id, secret_key, region)
          @api_client = api_client
          @client = Fog::Compute.new(:provider => 'AWS', :aws_access_key_id => access_key_id, :aws_secret_access_key => secret_key, :region => region)

        end

        # @param [Hash] opts
        def run!(opts)
          ami = resolve_ami(client.region)
          abort('No valid AMI found for region') unless ami

          security_group = ensure_security_group(opts[:grid], opts[:vpc])
          name = opts[:name ] || generate_name

          opts[:vpc] = default_vpc.id unless opts[:vpc]
          if opts[:subnet].nil?
            subnet = default_subnet(opts[:vpc], client.region+opts[:zone])
            opts[:subnet] = subnet.subnet_id
          else
            subnet = client.subnets.get(opts[:subnet])
          end
          dns_server = aws_dns_supported?(opts[:vpc]) ? '169.254.169.253' : '8.8.8.8'
          userdata_vars = {
              name: name,
              version: opts[:version],
              master_uri: opts[:master_uri],
              grid_token: opts[:grid_token],
              dns_server: dns_server
          }

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
          client.create_tags(instance.id, {'kontena_name' => name, 'kontena_grid' => opts[:grid]})
          node = nil
          ShellSpinner "Waiting for node #{name.colorize(:cyan)} join to grid #{opts[:grid].colorize(:cyan)} " do
            sleep 2 until node = instance_exists_in_grid?(opts[:grid], name)
          end
          labels = ["region=#{client.region}", "az=#{opts[:zone]}"]
          set_labels(node, labels)
        end

        ##
        # @param [String] grid
        # @return Fog::Compute::AWS::SecurityGroup
        def ensure_security_group(grid, vpc_id)
          group_name = "kontena_grid_#{grid}"
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
          security_group = client.security_groups.new(:name => name, :description => "Kontena Node", :vpc_id => vpc_id)
          security_group.save

          security_group.authorize_port_range(80..80)
          security_group.authorize_port_range(443..443)
          security_group.authorize_port_range(22..22)
          security_group.authorize_port_range(6783..6783, group: {security_group.owner_id => security_group.group_id}, ip_protocol: 'tcp')
          security_group.authorize_port_range(6783..6783, group: {security_group.owner_id => security_group.group_id}, ip_protocol: 'udp')
          security_group
        end


        # @param [String] region
        # @return String
        def resolve_ami(region)
          images = {
              'eu-central-1' => 'ami-74bbba69',
              'ap-northeast-1' => 'ami-1e77ff1e',
              'us-gov-west-1' => 'ami-f1d1b2d2',
              'sa-east-1' => 'ami-632ba17e',
              'ap-southeast-2' => 'ami-83f8b4b9',
              'ap-southeast-1' => 'ami-12060c40',
              'us-east-1' => 'ami-f396fa96',
              'us-west-2' => 'ami-99bfada9',
              'us-west-1' => 'ami-dbe71d9f',
              'eu-west-1' => 'ami-83e9c8f4'
          }
          images[region]
        end

        def default_subnet(vpc, zone)
          client.subnets.all('vpc-id' => vpc, 'availabilityZone' => zone).first
        end

        def default_vpc
          client.vpcs.all('isDefault' => true).first
        end

        def user_data(vars)
          cloudinit_template = File.join(__dir__ , '/cloudinit.yml')
          erb(File.read(cloudinit_template), vars)
        end

        def generate_name
          "#{super}-#{rand(1..99)}"
        end

        def instance_exists_in_grid?(grid, name)
          api_client.get("grids/#{grid}/nodes")['nodes'].find{|n| n['name'] == name}
        end

        def erb(template, vars)
          ERB.new(template).result(OpenStruct.new(vars).instance_eval { binding })
        end

        def set_labels(node, labels)
          data = {}
          data[:labels] = labels
          api_client.put("nodes/#{node['id']}", data, {}, {'Kontena-Grid-Token' => node['grid']['token']})
        end

        def aws_dns_supported?(vpc_id)
          response = client.describe_vpc_attribute(vpc_id,'enableDnsSupport')
          response.data[:body]['enableDnsSupport']
        end
      end
    end
  end
end
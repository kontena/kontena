require 'fileutils'
require 'erb'
require 'open3'
require 'shell-spinner'

module Kontena
  module Machine
    module Aws
      class NodeProvisioner
        include RandomName

        attr_reader :client, :api_client

        # @param [Kontena::Client] api_client Kontena api client
        # @param [String] access_key_id aws_access_key_id
        # @param [String] secret_key aws_secret_access_key
        # @param [String] region
        def initialize(api_client, access_key_id, secret_key, region)
          @api_client = api_client
          @client = Fog::Compute.new(:provider => 'AWS', :aws_access_key_id => access_key_id, :aws_secret_access_key => secret_key, :region => region)

        end

        def run!(opts)
          ami = resolve_ami(client.region)
          abort('No valid AMI found for region') unless ami

          security_group = ensure_security_group(opts[:grid])
          name = opts[:name ] || generate_name

          userdata_vars = {
              name: name,
              version: opts[:version],
              master_uri: opts[:master_uri],
              grid_token: opts[:grid_token],
          }

          response = client.run_instances(
              ami,
              1,
              1,
              'InstanceType'  => opts[:type],
              'SecurityGroup' => security_group.name,
              'KeyName'       => opts[:key_pair],
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
          ShellSpinner "Waiting for node #{name.colorize(:cyan)} join to grid #{opts[:grid].colorize(:cyan)} " do
            sleep 2 until instance_exists_in_grid?(opts[:grid], name)
          end



        end

        def ensure_security_group(grid)
          group_name = "kontena_grid_#{grid}"
          security_group = client.security_groups.get(group_name) || create_security_group(group_name)
          security_group

        end

        def create_security_group(name)
          security_group = client.security_groups.new(:name => name, :description => "Kontena Node")
          security_group.save

          security_group.authorize_port_range(80..80)
          security_group.authorize_port_range(443..443)
          security_group.authorize_port_range(22..22)
          security_group.authorize_port_range(6783..6783, group: {security_group.owner_id => security_group.group_id}, ip_protocol: 'tcp')
          security_group.authorize_port_range(6783..6783, group: {security_group.owner_id => security_group.group_id}, ip_protocol: 'udp')
          security_group
        end

        def resolve_ami(region)
          images = {
              'eu-central-1' => 'ami-bececaa3',
              'ap-northeast-1' => 'ami-f2338ff2',
              'us-gov-west-1' => 'ami-c75033e4',
              'sa-east-1' => 'ami-11e9600c',
              'ap-southeast-2' => 'ami-8f88c8b5',
              'ap-southeast-1' => 'ami-b6d8d4e4',
              'us-east-1' => 'ami-3d73d356',
              'us-west-2' => 'ami-85ada4b5',
              'us-west-1' => 'ami-1db04f59',
              'eu-west-1' => 'ami-0e104179'
          }
          images[region]
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


      end
    end
  end
end
require 'shell-spinner'

module Kontena
  module Machine
    module Aws
      class NodeDestroyer

        attr_reader :ec2, :api_client

        # @param [Kontena::Client] api_client Kontena api client
        # @param [String] access_key_id aws_access_key_id
        # @param [String] secret_key aws_secret_access_key
        # @param [String] region
        def initialize(api_client, access_key_id, secret_key, region = 'eu-west-1')
          @api_client = api_client
          @ec2 = ::Aws::EC2::Resource.new(
            region: region,
            credentials: ::Aws::Credentials.new(access_key_id, secret_key)
          )
        end

        def run!(grid, name)
          instances = ec2.instances({
            filters: [
              {name: 'tag:Name', values: [name]}
            ]
          })
          abort("Cannot find AWS instance #{name}") if instances.to_a.size == 0
          abort("There are multiple instances with name #{name}") if instances.to_a.size > 1
          instance = instances.first
          if instance
            ShellSpinner "Terminating AWS instance #{name.colorize(:cyan)} " do
              instance.terminate
              until instance.reload.state.name.to_s == 'terminated'
                sleep 2
              end
            end
          else
            abort "Cannot find instance #{name.colorize(:cyan)} in AWS"
          end
          node = api_client.get("grids/#{grid['id']}/nodes")['nodes'].find{|n| n['name'] == name}
          if node
            ShellSpinner "Removing node #{name.colorize(:cyan)} from grid #{grid['name'].colorize(:cyan)} " do
              api_client.delete("grids/#{grid['id']}/nodes/#{name}")
            end
          end
        end
      end
    end
  end
end

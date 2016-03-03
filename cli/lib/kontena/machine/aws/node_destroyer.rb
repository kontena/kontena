require 'shell-spinner'

module Kontena
  module Machine
    module Aws
      class NodeDestroyer

        attr_reader :client, :api_client

        # @param [Kontena::Client] api_client Kontena api client
        # @param [String] access_key_id aws_access_key_id
        # @param [String] secret_key aws_secret_access_key
        # @param [String] region
        def initialize(api_client, access_key_id, secret_key, region = 'eu-west-1')
          @api_client = api_client
          @client = Fog::Compute.new(:provider => 'AWS', :aws_access_key_id => access_key_id, :aws_secret_access_key => secret_key, :region => region)
        end

        def run!(grid, name)
          instance = client.servers.all({'tag:Name' => name}).first
          if instance
            ShellSpinner "Terminating AWS instance #{name.colorize(:cyan)} " do
              instance.destroy
              sleep 2 until client.servers.get(instance.id).state == 'terminated'
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

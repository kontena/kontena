require 'shell-spinner'

module Kontena
  module Machine
    module DigitalOcean
      class NodeDestroyer
        include RandomName

        attr_reader :client, :api_client

        # @param [Kontena::Client] api_client Kontena api client
        # @param [String] token Digital Ocean token
        def initialize(api_client, token)
          @api_client = api_client
          @client = DropletKit::Client.new(access_token: token)
        end

        def run!(grid, name)
          droplet = client.droplets.all.find{|d| d.name == name}
          if droplet
            ShellSpinner "Terminating DigitalOcean droplet #{name.colorize(:cyan)} " do
              client.droplets.delete(id: droplet.id)
              sleep 2 until client.droplets.find(id: droplet.id).is_a?(String)
            end
          else
            abort "Cannot find droplet #{name.colorize(:cyan)} in DigitalOcean"
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

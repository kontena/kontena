
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
            print "Destroying DigitalOcean droplet #{name} ."
            client.droplets.delete(id: droplet.id)
            until client.droplets.find(id: droplet.id).is_a?(String) do
              print '.'
              sleep 2
            end
            puts ' done!'
          else
            raise "Cannot find droplet with name #{name} in DigitalOcean"
          end
          node = api_client.get("grids/#{grid['id']}/nodes")['nodes'].find{|n| n['name'] == name}
          if node
            print "Removing node from Kontena master ..."
            api_client.delete("grids/#{grid['id']}/nodes/#{name}")
            puts " done!"
          end
        end
      end
    end
  end
end

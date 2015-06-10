require 'kontena/client'
require_relative '../common'

module Kontena::Cli::Grids
  class Registry
    include Kontena::Cli::Common

    def create(opts)
      require_api_url
      token = require_token
      preferred_node = opts.node

      registry = client(token).get("services/registry") rescue nil
      raise ArgumentError.new('Registry already exists') if registry

      nodes = client(token).get("grids/#{current_grid}/nodes")
      if preferred_node.nil?
        node = nodes['nodes'].find{|n| n['connected']}
        raise ArgumentError.new('Cannot find any online nodes') if node.nil?
      else
        node = nodes['nodes'].find{|n| n['connected'] && n['name'] == preferred_node }
        raise ArgumentError.new('Node not found') if node.nil?
      end

      data = {
        name: 'registry',
        stateful: true,
        image: 'registry:2.0',
        volumes: ['/tmp/registry'],
        env: [
          "REGISTRY_HTTP_ADDR=0.0.0.0:80"
        ],
        affinity: ["node==#{node['name']}"]
      }
      client(token).post("grids/#{current_grid}/services", data)
      result = client(token).post("services/registry/deploy", {})
      print 'deploying registry service '
      until client(token).get("services/registry")['state'] != 'deploying' do
        print '.'
        sleep 1
      end
      puts ' done'
      puts "Docker Registry 2.0 is now running at registry.kontena.local."
      puts "Note: OpenVPN connection is needed to establish connection to this registry."
      puts 'Note 2: you must set "--insecure-registry 10.81.0.0/16" to your client docker daemon before you are able to push to this registry.'
    end

    def delete
      require_api_url
      token = require_token

      registry = client(token).get("services/registry") rescue nil
      raise ArgumentError.new("Docker Registry service does not exist") if vpn.nil?

      client(token).delete("services/registry")
    end
  end
end

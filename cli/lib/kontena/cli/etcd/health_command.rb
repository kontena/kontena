require_relative 'common'

module Kontena::Cli::Etcd
  class HealthCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter "[NODE]", "Show health for specific node"

    def execute
      require_api_url
      token = require_token

      health = true

      if self.node
        node = client(token).get("nodes/#{current_grid}/#{self.node}")

        health = show_node(node)
      else
        nodes = client(token).get("grids/#{current_grid}/nodes")

        nodes['nodes'].each do |node|
          health &&= show_node(node)
        end
      end

      return health
    end

    def show_node(node)
      token = require_token

      if node['connected']
        node_health = client(token).get("nodes/#{current_grid}/#{node['id']}/health")

        return show_node_health node, node_health['etcd']
      else
        puts "Node #{node['name']} is offline"
        return false
      end
    end

    def show_node_health(node, etcd_health)
      if etcd_health['health']
        puts "Node #{node['name']} is healthy"
        return true
      elsif etcd_health['error']
        puts "Node #{node['name']} is unhealthy: #{etcd_health['error']}"
        return false
      else
        puts "Node #{node['name']} is unhealthy"
        return false
      end
    end
  end
end

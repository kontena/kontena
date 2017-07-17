require_relative 'common'
require 'kontena/cli/helpers/health_helper'

module Kontena::Cli::Etcd
  class HealthCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::HealthHelper

    parameter "[NODE]", "Show health for specific node"

    requires_current_master
    requires_current_grid

    def execute
      health = true

      if self.node
        node_health = client.get("nodes/#{current_grid}/#{self.node}/health")

        health = show_node_health(node_health)
      else
        nodes = client.get("grids/#{current_grid}/nodes")['nodes']

        nodes.each do |node|
          node_health = client.get("nodes/#{node['id']}/health")

          if !show_node_health(node_health)
            health = false
          end
        end
      end

      return health
    end

    # @return [Boolean]
    def show_node_health(node_health)
      if !node_health['connected']
        puts "#{health_icon :offline} Node #{node_health['name']} is offline"
        return false

      else
        etcd_health, status = node_etcd_health(node_health)

        puts "#{health_icon etcd_health} Node #{node_health['name']} etcd is #{status}"

        return etcd_health == :ok
      end
    end
  end
end

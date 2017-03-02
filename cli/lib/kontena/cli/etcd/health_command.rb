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
      require_api_url
      token = require_token

      health = true

      if self.node
        node_health = client.get("nodes/#{current_grid}/#{self.node}/health")

        health = show_node_health(node_health)
      else
        nodes = client.get("grids/#{current_grid}/nodes")['nodes']

        nodes.each do |node|
          node_health = client.get("nodes/#{current_grid}/#{node['name']}/health")

          if !show_node_health(node_health)
            health = false
          end
        end
      end

      return health
    end

    # @return [Boolean]
    def show_node_health(node_health)
      etcd_health = node_health['etcd_health']

      if !node_health['connected']
        puts "#{health_icon :offline} Node #{node_health['name']} is offline"
        return false
      elsif etcd_health['health']
        puts "#{health_icon :ok} Node #{node_health['name']} is healthy"
        return true
      elsif etcd_health['error']
        puts "#{health_icon :error} Node #{node_health['name']} is unhealthy: #{etcd_health['error']}"
        return false
      else
        puts "#{health_icon :error} Node #{node_health['name']} is unhealthy"
        return false
      end
    end
  end
end

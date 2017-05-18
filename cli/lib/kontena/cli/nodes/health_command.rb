require 'kontena/cli/helpers/health_helper'

module Kontena::Cli::Nodes
  class HealthCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::HealthHelper

    parameter "NODE", "Node"

    def execute
      require_api_url
      require_current_grid
      token = require_token

      node_health = client.get("nodes/#{current_grid}/#{self.node}/health")

      return show_node_health(node_health)
    end

    # @param node_health [Hash] GET /v1/nodes/:grid/:node/health JSON
    # @return [Boolean] true if healthy
    def show_node_health(node_health)
      if node_health['connected']
        puts "#{health_icon(:ok)} Node is online"
        return true
      elsif node_health['websocket_connection']['error']
        puts "#{health_icon(:offline)} Node is offline: #{node_health['websocket_connection']['error']}"
        return false
      else
        puts "#{health_icon(:offline)} Node is offline"
        return false
      end
    end
  end
end

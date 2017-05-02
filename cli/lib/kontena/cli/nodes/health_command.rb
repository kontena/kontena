require 'kontena/cli/helpers/health_helper'

module Kontena::Cli::Nodes
  class HealthCommand < Kontena::Command
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::HealthHelper

    parameter "NODE", "Node name"

    def execute
      require_api_url
      require_current_grid
      token = require_token

      node = client(token).get("nodes/#{current_grid}/#{self.node}")

      return show_node_health(node)
    end

    # @return [Boolean] true if healthy
    def show_node_health(node)
      if node['connected']
        puts "#{health_icon(:ok)} Node is online"
        return true
      else
        puts "#{health_icon(:offline)} Node is offline"
        return false
      end
    end
  end
end

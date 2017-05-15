require_relative '../helpers/health_helper'

module Kontena::Cli::Nodes
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::HealthHelper

    option ["--all"], :flag, "List nodes for all grids", default: false

    def node_initial(node, grid)
      if node['initial_member']
        return "#{node['node_number']} / #{grid['initial_size']}"
      else
        return "-"
      end
    end

    def node_labels(node)
      (node['labels'] || ['-']).join(",")
    end

    def show_grid_nodes(grid, nodes, multi: false)
      grid_health = grid_health(grid, nodes)

      nodes = nodes.sort_by{|n| n['node_number'] }
      nodes.each do |node|
        puts [
          "%s" % health_icon(node_health(node, grid_health)),
          "%-70.70s" % [multi ? "#{grid['name']}/#{node['name']}" : node['name']],
          "%-10s" % node['agent_version'],
          "%-10s" % (node['connected'] ? "online" : "offline"),
          "%-15s" % node['availability'],
          "%-10s" % node_initial(node, grid),
          "%s" % [node_labels(node)],
        ].join ' '
      end
    end

    def execute
      require_api_url
      require_current_grid
      token = require_token

      puts "%s %-70s %-10s %-10s %-15s %-10s %-s" % [health_icon(nil), "Name", "Version", "Status", "Availability", "Initial", "Labels"]

      if all?
        grids = client(token).get("grids")
        grids['grids'].each do |grid|
          nodes = client(require_token).get("grids/#{grid['id']}/nodes")['nodes']

          show_grid_nodes(grid, nodes, multi: true)
        end
      else
        grid = client(token).get("grids/#{current_grid}")
        nodes = client(require_token).get("grids/#{current_grid}/nodes")['nodes']

        show_grid_nodes(grid, nodes)
      end
    end
  end
end

require_relative '../helpers/health_helper'

module Kontena::Cli::Nodes
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::HealthHelper

    option ["--all"], :flag, "List nodes for all grids", default: false

    def node_health(node, grid_health)
      if !node['connected']
        return :offline
      elsif !node['initial_member']
        return :ok
      else
        return grid_health[:health]
      end
    end

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

    def show_grid_nodes(grid, multi: false)
      grid_nodes = client(require_token).get("grids/#{grid['id']}/nodes")
      grid_health = check_grid_health(grid, grid_nodes['nodes'])

      nodes = grid_nodes['nodes'].sort_by{|n| n['node_number'] }
      nodes.each do |node|
        puts [
          "%s" % health_icon(node_health(node, grid_health)),
          "%-70.70s" % [multi ? "#{grid['name']}/#{node['name']}" : node['name']],
          "%-10s" % node['agent_version'],
          "%-10s" % (node['connected'] ? "online" : "offline"),
          "%-10s" % node_initial(node, grid),
          "%s" % [node_labels(node)],
        ].join ' '
      end
    end

    def execute
      require_api_url
      require_current_grid
      token = require_token

      puts "%s %-70s %-10s %-10s %-10s %-s" % [health_icon(nil), "Name", "Version", "Status", "Initial", "Labels"]

      if all?
        grids = client(token).get("grids")
        grids['grids'].each do |grid|
          show_grid_nodes(grid, multi: true)
        end
      else
        grid = client(token).get("grids/#{current_grid}")

        show_grid_nodes(grid)
      end
    end
  end
end

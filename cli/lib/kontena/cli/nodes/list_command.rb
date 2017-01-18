require_relative '../helpers/health_helper'

module Kontena::Cli::Nodes
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::HealthHelper

    option ["--all"], :flag, "List nodes for all grids", default: false

    def node_status(node)
      if node['connected']
        return health_symbol(:ok), "online"
      else
        return health_symbol(:error), "offline"
      end
    end

    def node_intial(node, grid_health)
      if !node['initial_member']
        return health_symbol(nil), "-"
      else
        return health_symbol(node['connected'] ? grid_health[:health] : :unknown), "#{node['node_number']} / #{grid_health[:initial]}"
      end
    end

    def node_labels(node)
      (node['labels'] || ['-']).join(",")
    end

    def show_grid_nodes(grid, multi: false)
      grid_nodes = client(require_token).get("grids/#{current_grid}/nodes")
      grid_health = check_grid_health(grid, grid_nodes['nodes'])

      nodes = grid_nodes['nodes'].sort_by{|n| n['node_number'] }
      nodes.each do |node|
        puts [
          "%-70.70s" % [multi ? "#{grid['name']}/#{node['name']}" : node['name']],
          "%-10s" % node['agent_version'],
          "%s %-10s" % node_status(node),
          "%s %-10s" % node_intial(node, grid_health),
          "%s" % [node_labels(node)],
        ].join ' '
      end
    end

    def execute
      require_api_url
      require_current_grid
      token = require_token

      puts "%-70s %-10s %-12s %-12s %-40s" % ["Name", "Version", "  Status", "  Initial", "Labels"]

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

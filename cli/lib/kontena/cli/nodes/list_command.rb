require_relative '../helpers/health_helper'

module Kontena::Cli::Nodes
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::HealthHelper
    include Kontena::Cli::TableGenerator::Helper

    option ['-a', '--all'], :flag, 'List nodes for all grids', default: false

    requires_current_master
    requires_current_master_token
    requires_current_grid

    def node_name(node, grid)
      return node['name'] unless all?
      "#{grid['name']}/#{node['name']}"
    end

    def node_status(node)
      node['connected'] ? pastel.green('online') : pastel.red('offline')
    end

    def node_initial(node, grid)
      return '-' unless node['initial_member']
      "#{node['node_number']} / #{grid['initial_size']}"
    end

    def node_labels(node)
      (node['labels'] || ['-']).join(',')
    end

    def fields
      return ['name'] if quiet?
      {
        ' ' =>   'health_icon',
        name:    'name',
        version: 'agent_version',
        status:  'status',
        initial: 'initial',
        labels:  'labels'
      }
    end

    def grids
      all? ? client.get("grids")['grids'] : [client.get("grids/#{current_grid}")]
    end

    def node_data
      grids.flat_map do |grid|
        grid_nodes = []

        client.get("grids/#{grid['id']}/nodes")['nodes'].each do |node|
          node['name'] = node_name(node, grid)
          next if quiet?
          node['initial'] = node_initial(node, grid)
          node['status'] = node_status(node)
          node['labels'] = node_labels(node)
          grid_nodes << node
        end

        unless quiet?
          grid_health = grid_health(grid, grid_nodes)
          grid_nodes.each do |node|
            node['health_icon'] = health_icon(node_health(node, grid_health))
          end
        end

        grid_nodes
      end
    end

    def execute
      print_table(node_data)
    end
  end
end

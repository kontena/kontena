require_relative '../helpers/health_helper'
require_relative '../helpers/time_helper'

module Kontena::Cli::Nodes
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::HealthHelper
    include Kontena::Cli::Helpers::TimeHelper
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
      case node_status = node['status']
      when 'created'
        "#{pastel.dark('created')} #{time_since(node['created_at'], terse: true)}"
      when 'connecting'
        "#{pastel.cyan('connecting')} #{time_since(node['connected_at'], terse: true)}"
      when 'online'
        "#{pastel.green('online')} #{time_since(node['connected_at'], terse: true)}"
      when 'drain'
        "#{pastel.yellow('drain')}"
      when 'offline'
        "#{pastel.red('offline')} #{time_since(node['disconnected_at'], terse: true)}"
      else
        pastel.white(node_status.to_s)
      end
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
        name:    'name',
        version: 'agent_version',
        status:  'status',
        initial: 'initial',
        labels:  'labels',
      }
    end

    def grids
      all? ? client.get("grids")['grids'] : [client.get("grids/#{current_grid}")]
    end

    def grid_nodes(grid_name)
      client.get("grids/#{grid_name}/nodes")['nodes']
    end

    def node_data
      grids.flat_map do |grid|
        grid_nodes = []

        grid_nodes(grid['id']).each do |node|
          node['name'] = node_name(node, grid)
          grid_nodes << node
          next if quiet?
          node['agent_version'] ||= '-'
          node['initial'] = node_initial(node, grid)
          node['status'] = node_status(node)
          node['labels'] = node_labels(node)
        end

        unless quiet?
          grid_health = grid_health(grid, grid_nodes)
          grid_nodes.each do |node|
            node['name'] = health_icon(node_health(node, grid_health)) + " " + (node['name'] || node['node_id'])
          end
        end

        grid_nodes.sort_by { |n| n['node_number'] }
      end
    end

    def execute
      print_table(node_data)
    end
  end
end

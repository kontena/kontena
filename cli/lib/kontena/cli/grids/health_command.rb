require_relative 'common'
require "kontena/cli/helpers/health_helper"

module Kontena::Cli::Grids
  class HealthCommand < Kontena::Command
    include Kontena::Cli::Helpers::HealthHelper
    include Common

    parameter "[NAME]", "Grid name"

    def execute
      require_api_url

      grid = get_grid(name)
      grid_nodes = client(require_token).get("grids/#{grid['name']}/nodes")

      return show_grid_health(grid, grid_nodes['nodes'])
    end

    # Validate grid/nodes configuration for grid operation
    #
    # @return [Boolean] false if unhealthy
    def show_grid_health(grid, nodes)
      initial_size = grid['initial_size']
      minimum_size = grid['initial_size'] / 2 + 1 # a majority is required for etcd quorum

      grid_health = grid_health(grid, nodes)
      initial_nodes = nodes.select{|node| node['initial_member']}
      online_nodes = initial_nodes.select{|node| node['connected']}

      # configuration and status
      if initial_nodes.length == 0
        puts "#{health_icon :error} Grid does not have any initial nodes, and requires at least #{minimum_size} of #{initial_size} initial nodes for operation"
      elsif online_nodes.empty?
        puts "#{health_icon :error} Grid does not have any initial nodes online, and requires at least #{minimum_size} of #{initial_size} initial nodes for operation"
      elsif initial_nodes.length < minimum_size
        puts "#{health_icon :error} Grid only has #{initial_nodes.length} initial nodes, and requires at least #{minimum_size} of #{initial_size} initial nodes for operation"
      elsif online_nodes.length < minimum_size
        puts "#{health_icon :error} Grid only has #{online_nodes.length} initial nodes online, and requires at least #{minimum_size} of #{initial_size} initial nodes for operation"
      elsif initial_nodes.length < initial_size
        puts "#{health_icon :warning} Grid only has #{initial_nodes.length} initial nodes of #{initial_size} required for high-availability"
      elsif online_nodes.length < initial_size
        puts "#{health_icon :warning} Grid only has #{online_nodes.length} initial nodes online of #{initial_size} required for high-availability"
      elsif initial_nodes.length == 2
        puts "#{health_icon :warning} Grid only has #{initial_nodes.length} initial nodes, and is not high-availability"
      elsif initial_nodes.length == 1
        puts "#{health_icon :warning} Grid only has #{initial_nodes.length} initial node, and is not high-availability"
      else
        puts "#{health_icon :ok} Grid has all #{online_nodes.length} of #{initial_size} initial nodes online"
      end

      nodes.each do |node|
        node_health = node_health(node, grid_health)

        if node['connected']

        elsif node['initial_member']
          puts "#{health_icon grid_health} Initial node #{node['name']} is offline"
        else
          puts "#{health_icon node_health} Grid node #{node['name']} is offline"
        end
      end

      # operational if we have etcd quorum
      return online_nodes.length >= minimum_size
    end
  end
end

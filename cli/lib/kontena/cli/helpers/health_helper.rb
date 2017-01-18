module Kontena::Cli::Helpers
  module HealthHelper
    def health_icon(health)
      case health
      when nil
        " "
      when :ok
        pastel.green('⊛')
      when :warning
        pastel.yellow('⊙')
      when :error
        pastel.red('⊗')
      when :offline
        pastel.dark('⊝')
      else
        fail "Invalid health=#{health}"
      end
    end

    def show_health(health, message)
      STDOUT.puts "#{health_icon(health)} #{message}"
    end

    # Validate grid nodes configuration and status
    #
    def check_grid_health(grid, nodes)
      initial = grid['initial_size']
      minimum = grid['initial_size'] / 2 + 1 # a majority is required for etcd quorum

      nodes = nodes.select{|node| node['initial_member']}
      connected_nodes = nodes.select{|node| node['connected']}

      if connected_nodes.length < minimum
        health = :error
      elsif connected_nodes.length < initial
        health = :warning
      else
        health = :ok
      end

      return {
        initial: initial,
        minimum: minimum,
        nodes: nodes,
        created: nodes.length,
        connected: connected_nodes.length,
        health: health,
      }
    end

    # Validate grid/nodes configuration for etcd operation
    # @param grid [Hash] get(/grids/:grid) => { ... }
    # @param nodes [Array<Hash>] get(/grids/:grid/nodes)[nodes] => [ { ... } ]
    # @return [Boolean] false if unhealthy
    def show_grid_health(grid, nodes)
      grid_health = check_grid_health(grid, nodes)

      if grid_health[:created] == 0
        show_health :error, "Grid does not have any initial nodes, and requires at least #{grid_health[:minimum]} of #{grid_health[:initial]} nodes for operation"
      elsif grid_health[:created] < grid_health[:minimum]
        show_health :error, "Grid only has #{grid_health[:created]} of #{grid_health[:minimum]} initial nodes required for operation"
      elsif grid_health[:created] < grid_health[:initial]
        show_health :warning, "Grid only has #{grid_health[:created]} of #{grid_health[:initial]} initial nodes required for high-availability"
      elsif grid_health[:initial] <= 2
        show_health :warning, "Grid only has #{grid_health[:initial]} initial nodes, and is not high-availability"
      end

      grid_health[:nodes].each do |node|
        if !node['connected']
          show_health grid_health[:health], "Initial node #{node['name']} is disconnected"
        end
      end

      unless grid_health[:connected] < grid_health[:initial]
        show_health :ok, "Grid has all #{grid_health[:connected]} of #{grid_health[:initial]} initial nodes connected"
      end

      return grid_health[:health] != :error
    end

    # Check node health
    #
    # @param node [Hash] get(/nodes/:grid/:node)
    # @return [Boolean] false if unhealthy
    def show_node_health(node)
      if !node['connected']
        show_health :offline, "Node is not connected"
        return false
      else
        show_health :ok, "Node is connected"
        return true
      end
    end
  end
end

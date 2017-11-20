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

    # Validate grid nodes configuration and status
    #
    # @param grid [Hash] get(/grids/:grid) => { ... }
    # @param nodes [Array<Hash>] get(/grids/:grid/nodes)[nodes] => [ { ... } ]
    # @return [Symbol] health
    def grid_health(grid, nodes)
      initial = grid['initial_size']
      minimum = grid['initial_size'] / 2 + 1 # a majority is required for etcd quorum

      online = nodes.select{|node| node['initial_member'] && node['connected']}

      if online.length < minimum
        return :error
      elsif online.length < initial
        return :warning
      else
        return :ok
      end
    end

    # Validate grid node status based on the grid health
    #
    # @param node [Hash] GET /nodes/:grid/:node
    # @param grid_health [Symbol] @see #grid_health
    # @return [Symbol] health
    def node_health(node, grid_health)
      if node['initial_member']
        return node['connected'] ? grid_health : :offline
      else
        return node['connected'] ? :ok : :offline
      end
    end

    # @param node_etcd_health [Hash{health: String, error: String}]
    # @return [Symbol, String]
    def node_etcd_health(node_etcd_health)
      if node_etcd_health['health']
        return :ok, "healthy"
      elsif node_etcd_health['error']
        return :error, "unhealthy: #{node_etcd_health['error']}"
      else
        return :error, "unhealthy"
      end
    end
  end
end

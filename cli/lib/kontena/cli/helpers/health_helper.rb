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

    # @return [Symbol]
    # @return [String]
    def node_etcd_health(node_health)
      etcd_health = node_health['etcd_health']

      if !node_health['connected']
        return :offline, "unknown"
      elsif node_health['errors'] && node_health['errors']['etcd_health']
        return :offline, "error: #{node_health['errors']['etcd_health']}"
      elsif etcd_health['health']
        return :ok, "healthy"
      elsif etcd_health['error']
        return :error, "unhealthy: #{etcd_health['error']}"
      else
        return :error, "unhealthy"
      end
    end

    # Return an approximation of how long ago the given time was.
    # @param time [String]
    # @param terse [Boolean] very terse output (2-3 chars wide)
    def time_since(time, terse: false)
      return '' if time.nil? || time.empty?

      dt = Time.now - Time.parse(time)

      dt_s = dt.to_i
      dt_m, dt_s = dt_s / 60, dt_s % 60
      dt_h, dt_m = dt_m / 60, dt_m % 60
      dt_d, dt_h = dt_h / 60, dt_h % 60

      parts = []
      parts << "%dd" % dt_d if dt_d > 0
      parts << "%dh" % dt_h if dt_h > 0
      parts << "%dm" % dt_m if dt_m > 0
      parts << "%ds" % dt_s

      if terse
        return parts.first
      else
        return parts.join('')
      end
    end
  end
end

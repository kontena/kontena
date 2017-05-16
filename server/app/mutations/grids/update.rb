module Grids
  class Update < Mutations::Command

    required do
      model :grid
      model :user
    end

    optional do
      hash :stats do
        optional do
          hash :statsd do
            required do
              string :server
              integer :port
            end
          end
        end
      end
      array :trusted_subnets do
        string
      end
      array :default_affinity do
        string
      end
      hash :logs do
        required do
          string :forwarder, in: ['fluentd', 'none'] # Only fluentd now supported, none removes log shipping
        end
        optional do
          model :opts, class: Hash
        end
      end
    end

    def validate
      add_error(:user, :invalid, 'Operation not allowed') unless user.can_update?(grid)
      if self.trusted_subnets
        self.trusted_subnets.each do |subnet|
          begin
            IPAddr.new(subnet)
          rescue IPAddr::InvalidAddressError
            add_error(:trusted_subnets, :invalid, "Invalid trusted_subnet #{subnet}")
          end
        end
      end
      if self.logs
        case self.logs[:forwarder]
        when 'fluentd'
          validate_fluentd_opts(self.logs[:opts])
        end
      end
    end

    def execute
      attributes = {}
      attributes[:stats] = self.stats if self.stats
      attributes[:trusted_subnets] = self.trusted_subnets if self.trusted_subnets
      attributes[:default_affinity] = self.default_affinity if self.default_affinity

      if self.logs
        if self.logs[:forwarder] == 'none'
          self.grid.grid_logs_opts = nil
        else
          self.grid.grid_logs_opts = GridLogsOpts.new(forwarder: self.logs[:forwarder], opts: self.logs[:opts])
        end
      end
      grid.update_attributes(attributes)
      if grid.errors.size > 0
        grid.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        return
      end

      self.notify_nodes

      grid
    end

    def notify_nodes
      Celluloid::Future.new {
        grid.host_nodes.connected.each do |node|
          plugger = Agent::NodePlugger.new(grid, node)
          plugger.send_node_info
        end
        GridScheduler.new(grid).reschedule
      }
    end

    def validate_fluentd_opts(opts)
      address = opts['fluentd-address']
      add_error(:logs, :forwarder, 'fluentd-address option must be given') unless address
    end
  end
end

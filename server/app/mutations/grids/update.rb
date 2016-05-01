module Grids
  class Update < Mutations::Command

    required do
      model :grid
      model :user
    end

    optional do
      hash :stats do
        required do
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
    end

    def execute
      attributes = {}
      if self.stats
        attributes[:stats] = self.stats
      end
      if self.trusted_subnets
        attributes[:trusted_subnets] = self.trusted_subnets
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
      }
    end
  end
end

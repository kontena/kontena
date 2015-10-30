module Agent
  class NodeUnplugger

    attr_reader :node, :grid

    # @param [HostNode] node
    def initialize(node)
      @node = node
      @grid = node.grid
    end

    def unplug!
      Celluloid::Future.new {
        begin
          self.update_node
          self.reschedule_services
        rescue => exc
          puts exc.message
        end
      }
    end

    def update_node
      node.update_attribute(:connected, false)
    end

    def reschedule_services
      sleep 5
      grid.grid_services.each do |service|
        if service.stateless? && !service.deploying?
          reschedule_service(service)
        end
      end
    end

    def reschedule_service(service)
      GridServices::Deploy.run(
        grid_service: service,
        strategy: service.strategy
      )
    end
  end
end

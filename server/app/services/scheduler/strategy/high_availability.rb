module Scheduler
  module Strategy
    class HighAvailability

      ##
      # @param [GridService] grid_service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      # @return [HostNode,NilClass]
      def find_node(grid_service, instance_number, nodes)
        if grid_service.stateless?
          candidates = self.sort_candidates(nodes, grid_service)
          candidates.first
        else
          prev_container = grid_service.containers.volumes.find_by(
            name: "#{grid_service.name}-#{instance_number}-volumes"
          )
          if prev_container
            prev_container.host_node
          else
            candidates = self.sort_candidates(nodes, grid_service)
            candidates.first
          end
        end
      end

      def sort_candidates(nodes, grid_service)
        nodes.shuffle.sort_by{|node|
          node.reload.containers.scoped.where(grid_service_id: grid_service.id).count
        }
      end
    end
  end
end

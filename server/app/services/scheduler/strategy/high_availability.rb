module Scheduler
  module Strategy
    class HighAvailability

      ##
      # @param [GridService] grid_service
      # @param [String] container_name
      # @param [Array<HostNode>] nodes
      # @return [HostNode,NilClass]
      def find_node(grid_service, container_name, nodes)
        if grid_service.stateless?
          candidates = self.sort_candidates(nodes, grid_service)
          candidates.first
        else
          prev_container = grid_service.containers.volumes.find_by(name: "#{container_name}-volumes")
          if prev_container
            prev_container.host_node
          else
            candidates = self.sort_candidates(nodes, grid_service)
            candidates.first
          end
        end
      end

      def sort_candidates(nodes, grid_service)
        nodes.sort_by{|node|
          node.containers.where(grid_service_id: grid_service.id).count
        }
      end
    end
  end
end

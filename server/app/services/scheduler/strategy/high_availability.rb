module Scheduler
  module Strategy
    class HighAvailability

      # @param [Integer] node_count
      # @param [Integer] instance_count
      def instance_count(node_count, instance_count)
        instance_count.to_i
      end

      ##
      # @param [GridService] grid_service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      # @param [String] rev
      # @return [HostNode,NilClass]
      def find_node(grid_service, instance_number, nodes, rev = nil)
        if grid_service.stateless?
          candidates = self.sort_candidates(nodes, grid_service, instance_number)
          candidates.first
        else
          prev_container = grid_service.containers.volumes.find_by(
            name: "#{grid_service.name}-#{instance_number}-volumes"
          )
          if prev_container && nodes.include?(prev_container.host_node)
            nodes.find{|n| n == prev_container.host_node }
          else
            candidates = self.sort_candidates(nodes, grid_service, instance_number)
            candidates.first
          end
        end
      end

      # @param [Array<HostNode>] nodes
      # @param [GridService] grid_service
      # @param [Integer] instance_number
      def sort_candidates(nodes, grid_service, instance_number)
        nodes.shuffle.sort_by{|node|
          container = node.containers.find_by(name: "#{grid_service.name}-#{instance_number}")
          if container
            rank = 0
          else
            rank = 1
          end

          [node.schedule_counter, rank]
        }
      end
    end
  end
end

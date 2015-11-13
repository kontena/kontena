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
          candidates = self.sort_candidates(nodes, grid_service, rev)
          candidates.first
        else
          prev_container = grid_service.containers.volumes.find_by(
            name: "#{grid_service.name}-#{instance_number}-volumes"
          )
          if prev_container
            prev_container.host_node
          else
            candidates = self.sort_candidates(nodes, grid_service, rev)
            candidates.first
          end
        end
      end

      # @param [Array<HostNode>] nodes
      # @param [GridService] grid_service
      # @param [String, NilClass] rev
      def sort_candidates(nodes, grid_service, rev = nil)
        nodes.shuffle.sort_by{|node|
          query = node.reload.containers.scoped.where(grid_service_id: grid_service.id)
          query = query.where(deploy_rev: rev) if rev
          query.count
        }
      end
    end
  end
end

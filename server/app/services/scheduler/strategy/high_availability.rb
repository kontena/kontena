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
      # @return [HostNode,NilClass]
      def find_node(grid_service, instance_number, nodes)
        if grid_service.stateless?
          find_stateless_node(grid_service, instance_number, nodes)
        else
          find_stateful_node(grid_service, instance_number, nodes)
        end
      end

      # @param [GridService] grid_service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      # @return [HostNode,NilClass]
      def find_stateless_node(grid_service, instance_number, nodes)
        candidates = self.sort_candidates(nodes, grid_service, instance_number)
        candidates.first
      end

      # @param [GridService] grid_service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      # @return [HostNode,NilClass]
      def find_stateful_node(grid_service, instance_number, nodes)
        prev_container = grid_service.containers.volumes.service_instance(
          grid_service, instance_number
        ).first
        if prev_container
          nodes.find{|n| n == prev_container.host_node }
        else
          candidates = self.sort_candidates(nodes, grid_service, instance_number)
          candidates.first
        end
      end

      # @param [Array<HostNode>] nodes
      # @param [GridService] grid_service
      # @param [Integer] instance_number
      def sort_candidates(nodes, grid_service, instance_number)
        nodes.shuffle.sort_by{|node|
          rank = 10.0
          rank += instance_rank(node, grid_service, instance_number)
          rank += memory_rank(node)
          zone_counter = availability_zone_count(node, nodes)

          [zone_counter, node.schedule_counter, rank]
        }
      end

      # @param [HostNode] node
      # @param [GridService] grid_service
      # @param [Fixnum] instance_number
      # @return [Float]
      def instance_rank(node, grid_service, instance_number)
        container = node.containers.service_instance(grid_service, instance_number).first
        if container
          -5.0
        else
          0.0
        end
      end

      # @param [HostNode] node
      # @return [Float]
      def memory_rank(node)
        stats = node.host_node_stats.last
        if stats
          stats.memory['used'].to_f / node.mem_total.to_f
        else
          0.0
        end
      end

      # @param [HostNode] node
      # @param [Array<HostNode>] nodes
      # @return [FixNum]
      def availability_zone_count(node, nodes)
        nodes_in_zone = nodes.select{|n|
          node.availability_zone == n.availability_zone
        }
        zone_counter = 0
        nodes_in_zone.each{|n| zone_counter += n.schedule_counter }

        zone_counter
      end
    end
  end
end

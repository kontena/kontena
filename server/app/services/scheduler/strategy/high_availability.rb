module Scheduler
  module Strategy
    class HighAvailability

      # @param [Integer] node_count
      # @param [Integer] instance_count
      def instance_count(node_count, instance_count)
        instance_count.to_i
      end

      # @return [ActiveSupport::Duration]
      def host_grace_period
        2.minutes
      end

      # @param [GridService] grid_service
      # @param [Integer] instance_number
      # @param [Array<Scheduler::Node>] nodes
      # @return [Scheduler::Node,NilClass]
      def find_node(grid_service, instance_number, nodes)
        if grid_service.stateless?
          find_stateless_node(grid_service, instance_number, nodes)
        else
          find_stateful_node(grid_service, instance_number, nodes)
        end
      end

      # @param [GridService] grid_service
      # @param [Integer] instance_number
      # @param [Array<Scheduler::Node>] nodes
      # @return [Scheduler::Node,NilClass]
      def find_stateless_node(grid_service, instance_number, nodes)
        candidates = self.sort_candidates(nodes, grid_service, instance_number)
        candidates.first
      end

      # @param [GridService] grid_service
      # @param [Integer] instance_number
      # @param [Array<Scheduler::Node>] nodes
      # @return [Scheduler::Node,NilClass]
      def find_stateful_node(grid_service, instance_number, nodes)
        prev_instance = grid_service.grid_service_instances.has_node.find_by(
          instance_number: instance_number
        )
        if prev_instance
          nodes.find{ |n| n.node == prev_instance.host_node }
        else
          candidates = self.sort_candidates(nodes, grid_service, instance_number)
          candidates.first
        end
      end

      # @param [Array<Scheduler::Node>] nodes
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

      # @param [Scheduler::Node] node
      # @param [GridService] grid_service
      # @param [Integer] instance_number
      # @return [Float]
      def instance_rank(node, grid_service, instance_number)
        # ask all instances so that mongoid can cache query
        current_instances = node.grid_service_instances.where(grid_service_id: grid_service.id).to_a
        if current_instances.any? { |i| i.instance_number == instance_number}
          -5.0
        else
          0.0
        end
      end

      # @param [Scheduler::Node] node
      # @return [Float]
      def memory_rank(node)
        stats = node.latest_stats
        unless stats.empty?
          stats['memory']['used'].to_f / node.mem_total.to_f
        else
          0.0
        end
      end

      # @param [Scheduler::Node] node
      # @param [Array<HostNode>] nodes
      # @return [Integer]
      def availability_zone_count(node, nodes)
        nodes_in_zone = nodes.select{|n|
          node.availability_zone == n.availability_zone
        }
        zone_counter = 0
        nodes_in_zone.each{ |n| zone_counter += n.schedule_counter }

        zone_counter
      end
    end
  end
end

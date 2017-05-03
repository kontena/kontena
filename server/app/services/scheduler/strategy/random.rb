require_relative 'common'

module Scheduler
  module Strategy
    class Random
      include Scheduler::Strategy::Common

      # @return [ActiveSupport::Duration]
      def host_grace_period
        30.seconds
      end

      # @param [GridService] grid_service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      # @return [HostNode]
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
      # @return [Scheduler::Node]
      def find_stateless_node(grid_service, instance_number, nodes)
        if deployment?
          nodes.sample
        else 
          prev_instance = grid_service.grid_service_instances.find_by(
            grid_service: grid_service, instance_number: instance_number
          )
          if prev_instance
            node = nodes.find{ |n| n.node == prev_instance.host_node }
            return node if node
          end
          nodes.sample
        end
      end

      # @param [GridService] grid_service
      # @param [Integer] instance_number
      # @param [Array<Scheduler::Node>] nodes
      # @return [Scheduler::Node]
      def find_stateful_node(grid_service, instance_number, nodes)
        prev_instance = grid_service.grid_service_instances.find_by(
          grid_service: grid_service, instance_number: instance_number
        )
        if prev_instance
          nodes.find{ |n| n.node == prev_instance.host_node }
        else
          nodes.sample
        end
      end
    end
  end
end

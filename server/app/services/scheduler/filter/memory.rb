module Scheduler
  module Filter
    class Memory

      ##
      # @param [GridService] service
      # @param [Integer] instance_number
      # @param [Array<HostNode>] nodes
      # @return [Array<HostNode>]
      def for_service(service, instance_number, nodes)
        candidates = nodes.dup
        memory = service.memory || service.memory_swap
        unless memory
          container = service.containers.first
          if container
            stats = container.container_stats.last
            memory = stats.memory['usage'] * 1.25 if stats
          end
        end

        return candidates unless memory # we cannot calculate so let's return all candidates
        candidates.delete_if{|c|
          reject_candidate?(c, memory, service, instance_number)
        }

        candidates
      end

      # @param [HostNode] candidate
      # @param [Float] memory
      # @param [GridService] service
      # @param [Integer] instance_number
      def reject_candidate?(candidate, memory, service, instance_number)
        return true if candidate.mem_total.to_i < memory

        node_stat = candidate.host_node_stats.last
        return false if node_stat.nil?

        all_used = node_stat.memory['total'] - node_stat.memory['free']
        mem_used = all_used - (node_stat.memory['cached'] + node_stat.memory['buffers'])
        mem_free = node_stat.memory['total'] - mem_used

        if instance = candidate.containers.service_instance(service, instance_number).first
          mem_free += memory
        end

        return true if mem_free < memory

        false
      end
    end
  end
end

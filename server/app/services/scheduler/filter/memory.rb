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
          memory = resolve_memory_from_stats(service, instance_number)
        end

        return candidates if memory == 0 # we cannot calculate so let's return all candidates

        candidates.delete_if { |c|
          reject_candidate?(c, memory, service, instance_number)
        }

        if candidates.empty?
          raise Scheduler::Error, "Did not find any nodes with sufficient free memory: #{memory}"
        end

        candidates
      end

      # @param service [GridService]
      # @param instance_number [Integer]
      # @return [Integer]
      def resolve_memory_from_stats(service, instance_number)
        memory = 0
        service_instance = fetch_service_instance(service, instance_number)
        if service_instance && !service_instance.latest_stats.empty?
          usage = service_instance.latest_stats.dig('memory', 'usage')
          memory = usage * 1.25 if usage
        end

        memory.to_i
      end

      # @param service [GridService]
      # @param instance_number [Integer]
      # @param candidate [HostNode]
      # @return [GridServiceInstance, NilClass]
      def fetch_service_instance(service, instance_number, candidate = nil)
        service.grid_service_instances.to_a.find { |i|
          i.instance_number == instance_number && (candidate.nil? || i.host_node_id == candidate.id)
        }
      end

      # @param [HostNode] candidate
      # @param [Float] memory
      # @param [GridService] service
      # @param [Integer] instance_number
      def reject_candidate?(candidate, memory, service, instance_number)
        return false if fetch_service_instance(service, instance_number, candidate)
        return true if candidate.mem_total.to_i < memory

        node_stat = candidate.latest_stats
        return false if node_stat.empty?

        node_mem = node_stat['memory']
        all_used = node_mem['total'] - node_mem['free']
        mem_used = all_used - (node_mem['cached'] + node_mem['buffers'])
        mem_free = node_mem['total'] - mem_used

        return true if mem_free < memory

        false
      end
    end
  end
end

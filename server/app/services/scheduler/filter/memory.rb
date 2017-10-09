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

        return candidates unless memory # we cannot calculate so let's return all candidates

        candidates.delete_if { |c|
          reject_candidate?(c, memory, service, instance_number)
        }

        if candidates.empty?
          raise Scheduler::Error, "Did not find any nodes with sufficient free memory: #{memory}"
        end

        candidates
      end

      def resolve_memory_from_stats(service, instance_number)
        cache_key = "scheduler:mem:filter:#{service.id}-#{instance_number}"
        memory = self.class.cache[cache_key]
        unless memory
          container = service.containers.to_a.find { |c| c.instance_number == instance_number }
          if container
            stats = container.container_stats.latest
            if stats
              memory = stats.memory['usage'] * 1.25
              self.class.cache[cache_key] = memory
            end
          end
        end
        unless memory
          memory = 256.megabytes # just a default if we cannot resolve anything
        end

        memory
      end

      # @param service [GridService]
      # @param instance_number [Integer]
      def fetch_service_instance(service, instance_number)
        service.grid_service_instances.to_a.find { |i| i.instance_number == instance_number }
      end

      # @param [HostNode] candidate
      # @param [Float] memory
      # @param [GridService] service
      # @param [Integer] instance_number
      def reject_candidate?(candidate, memory, service, instance_number)
        return false if fetch_service_instance(service, instance_number)
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

      # @return [LruRedux::TTL::ThreadSafeCache]
      def self.cache
        @cache ||= LruRedux::TTL::ThreadSafeCache.new(1000, 60 * 5)
      end
    end
  end
end

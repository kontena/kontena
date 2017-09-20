module Rpc
  class NodeServicePodHandler
    include Logging

    def initialize(grid)
      @grid = grid
      @lru_cache = LruRedux::ThreadSafeCache.new(1000)
    end

    # @param service_instance [GridServiceInstance]
    def cached_pod(service_instance)
      return nil unless service_instance.grid_service

      # TODO Do we need any other attrbutes for the composed key?
      cache_key = {
        id: service_instance.id,
        deploy_rev: service_instance.deploy_rev,
        desired_state: service_instance.desired_state
      }
      serializer = ServicePodSerializer.new(service_instance)
      pod_hash = @lru_cache.getset(cache_key) {
        debug "pod_cache miss"
        serializer.to_hash
      }
      # hooks cannot be cached
      pod_hash[:hooks] = serializer.build_hooks

      pod_hash
    end

    # @param [String] id
    # @return [Array<Hash>]
    def list(id)
      start = Time.now.to_f
      node = @grid.host_nodes.find_by(node_id: id)
      raise 'Node not found' unless node
      raise 'Migration not done' unless migration_done?

      service_pods = node.grid_service_instances.includes(:grid_service).map { |i|
        cached_pod(i)
      }.compact
      end_time = Time.now.to_f
      debug "pod list rpc took: #{((end_time-start) * 1000).to_i}ms"
      { service_pods: service_pods }
    end

    # @param id [String]
    # @param pod [Hash]
    def set_state(id, pod)
      node = @grid.host_nodes.find_by(node_id: id)
      raise 'Node not found' unless node

      service_instance = node.grid_service_instances.find_by(
        grid_service_id: pod['service_id'], instance_number: pod['instance_number']
      )
      raise 'Instance not found' unless service_instance

      service_instance.set(
        rev: pod['rev'],
        state: pod['state'],
        error: pod['error'],
      )
      {}
    end

    # @param id [String]
    # @param pod [Hash]
    # @param hook [Hash]
    def mark_oneshot_hook(id, pod, hook)
      node = @grid.host_nodes.find_by(node_id: id)
      raise 'Node not found' unless node

      service_instance = node.grid_service_instances.find_by(
        grid_service_id: pod['service_id'], instance_number: pod['instance_number']
      )
      raise 'Instance not found' unless service_instance

      oneshot_hook = service_instance.grid_service.hooks.to_a.find{ |h|
        h.oneshot && h.id.to_s == hook['id']
      }
      raise "Hook not found: #{hook}" unless oneshot_hook
      oneshot_hook.push(:done => pod['instance_number'].to_s)

      {}
    end

    # @param [String] id
    # @param [Hash] event
    def event(id, event)
      node = @grid.host_nodes.find_by(node_id: id)
      return unless node

      service = GridService.where(id: event['service_id'], grid_id: node.grid_id).first
      return unless service

      EventLog.create(
        severity: event['severity'] || EventLog::INFO,
        msg: event['data'],
        type: event['type'],
        grid_id: node.grid_id,
        host_node_id: node.id,
        stack_id: service.stack_id,
        grid_service_id: service.id,
        meta: {
          instance_number: event['instance_number']
        }
      )
    end

    # @return [Boolean]
    def migration_done?
      if @migration_done.nil?
        last = SchemaMigration.order_by(:id.asc).last
        if last
          @migration_done = last.version >= 20
        else
          @migration_done = false
        end
      end
      @migration_done
    end
  end
end

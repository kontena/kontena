module Rpc
  class NodeServicePodHandler
    include Logging

    # @params [HostNode] node
    def initialize(node)
      @node = node
      @lru_cache = LruRedux::ThreadSafeCache.new(1000)
    end

    def cached_pod(service_instance)
      # TODO Do we need any other attrbutes for the composed key?
      cache_key = {
        id: service_instance.id,
        deploy_rev: service_instance.deploy_rev,
        desired_state: service_instance.desired_state
      }
      @lru_cache.getset(cache_key) {
        debug "pod_cache miss"
        ServicePodSerializer.new(service_instance).to_hash if service_instance.grid_service
      }
    end

    # @return [Array<Hash>]
    def list
      start = Time.now.to_f

      raise 'Migration not done' unless migration_done?

      service_pods = @node.grid_service_instances.includes(:grid_service).map { |i|
        cached_pod(i)
      }.compact
      end_time = Time.now.to_f
      debug "pod list rpc took: #{((end_time-start) * 1000).to_i}ms"
      { service_pods: service_pods }
    end

    # @param [Hash] pod
    def set_state(pod)
      service_instance = @node.grid_service_instances.find_by(
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

    # @param [Hash] event
    def event(event)
      service = GridService.where(id: event['service_id'], grid_id: @node.grid_id).first
      return unless service

      EventLog.create(
        severity: event['severity'] || EventLog::INFO,
        msg: event['data'],
        type: event['type'],
        grid_id: @node.grid_id,
        host_node_id: @node.id,
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

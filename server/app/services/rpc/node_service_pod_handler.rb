module Rpc
  class NodeServicePodHandler

    def initialize(grid)
      @grid = grid
    end

    # @param [String] id
    # @return [Array<Hash>]
    def list(id)
      node = @grid.host_nodes.find_by(node_id: id)
      raise 'Node not found' unless node
      raise 'Migration not done' unless migration_done?

      service_pods = node.grid_service_instances.includes(:grid_service).map { |i|
        ServicePodSerializer.new(i).to_hash if i.grid_service
      }.compact

      { service_pods: service_pods }
    end

    # @param [String] id
    # @param [Hash] pod
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
        last = SchemaMigration.last
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

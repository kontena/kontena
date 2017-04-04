module Rpc
  class NodeServicePodHandler

    def initialize(grid)
      @grid = grid
    end

    # @param [String] id
    # @return [Array<Hash>]
    def list(id)
      node = @grid.host_nodes.find_by(node_id: id)
      return { error: 'Node not found' } unless node
      return { error: 'Migration not done' } unless migration_done?
      service_pods = node.grid_service_instances.includes(:grid_service).map { |i|
        ServicePodSerializer.new(i).to_hash if i.grid_service
      }.compact

      { service_pods: service_pods }
    rescue
      { error: 'Internal server error' }
    end

    # @param [String] id
    # @param [Hash] pod
    def set_state(id, pod)
      node = @grid.host_nodes.find_by(node_id: id)
      return { error: 'Node not found' } unless node

      service_instance = node.grid_service_instances.find_by(
        grid_service_id: pod['service_id'], instance_number: pod['instance_number']
      )
      if service_instance
        service_instance.set(
          state: pod['state'],
          rev: pod['rev']
        )
        {}
      else
        { error: 'Instance not found' }
      end
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

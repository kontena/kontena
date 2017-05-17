V1::GridsApi.route('grid_event_logs') do |r|

  # GET /v1/grids/:id/event_logs
  r.get do
    r.is do
      scope = @grid.event_logs

      unless r['nodes'].nil?
        nodes = r['nodes'].split(',').map { |name|
          @grid.host_nodes.find_by(name: name).try(:id)
        }.compact

        scope = scope.where(host_node_id: {:$in => nodes})
      end
      unless r['stacks'].nil?
        stacks = r['stacks'].split(',').map { |stack|
          @grid.stacks.find_by(name: stack).try(:id)
        }.compact

        scope = scope.where(stack_id: {:$in => stacks})
      end
      unless r['services'].nil?
        services = r['services'].split(',').map { |service|
          stack_name, service_name = service.split('/')
          stack = @grid.stacks.find_by(name: stack_name)
          if stack
            @grid.grid_services.find_by(stack_id: stack.id,name: service_name).try(:id)
          end
        }.compact

        scope = scope.where(grid_service_id: {:$in => services})
      end

      render_event_logs(r, scope)
    end
  end
end

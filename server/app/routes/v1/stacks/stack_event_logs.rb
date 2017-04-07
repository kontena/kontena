V1::StacksApi.route('stack_event_logs') do |r|

  # GET /v1/stacks/:grid_name/:stack_name/event_logs
  r.get do
    r.is do
      scope = EventLog.where(stack_id: @stack.id).includes(:grid, :stack, :grid_service, :host_node)
      render_event_logs(r, scope)
    end
  end
end

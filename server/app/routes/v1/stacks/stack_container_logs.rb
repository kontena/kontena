V1::StacksApi.route('stack_container_logs') do |r|

  # GET /v1/stacks/:grid/:name
  r.get do
    r.is do

      nodes = nil
      services = nil
      scope = @stack.grid.container_logs.includes(:grid_service, :host_node)
      services = @stack.grid_services.to_a
      scope = scope.where(grid_service_id: {:$in => services}) if services
      scope = scope.where(host_node_id: {:$in => nodes}) if nodes
      scope = scope.where(name: r['container']) unless r['container'].nil?
      scope = scope.where(:$text => {:$search => r['search']}) unless r['search'].nil?

      render_container_logs(r, scope)
    end
  end
end

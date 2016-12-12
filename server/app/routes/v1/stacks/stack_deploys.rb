V1::StacksApi.route('stack_deploys') do |r|

  # GET /v1/stacks/:grid_name/:stack_name/deploys
  r.get do
    r.on ':id' do |id|
      @stack_deploy = @stack.stack_deploys.find_by(id: id)
      halt_request(404, {error: 'Not found'}) if !@stack_deploy

      render('stack_deploys/show')
    end
  end
end

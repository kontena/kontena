require_relative '../../../mutations/stacks/create'

V1::GridsApi.route('grid_stacks') do |r|

  # POST /v1/grids/:grid/stacks
  r.post do
    r.is do
      data = parse_json_body
      data[:grid] = @grid
      outcome = Stacks::Create.run(data)

      if outcome.success?
        @stack = outcome.result
        audit_event(request, @grid, @stack, 'create')
        response.status = 201
        render('stacks/show')
      else
        response.status = 422
        {error: outcome.errors.message}
      end
    end
  end

  # GET /v1/grids/:grid/stacks
  r.get do
    r.is do
      @stacks = @grid.stacks.where(:name.ne => Stack::NULL_STACK).includes(:grid, :grid_services)
      render('stacks/index')
    end
  end
end

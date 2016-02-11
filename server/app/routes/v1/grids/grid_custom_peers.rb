require_relative '../../../mutations/grids/add_custom_peer'
require_relative '../../../mutations/grids/remove_custom_peer'
V1::GridsApi.route('grid_custom_peers') do |r|

  # POST /v1/grids/:name/custom_peers
  r.post do
    data = parse_json_body
    outcome = Grids::AddCustomPeer.run(
      grid: @grid,
      current_user: current_user,
      peer: data['peer']
    )
    if outcome.success?
      audit_event(r, @grid, @grid, 'add custom peer')
      response.status = 201
      {}
    else
      response.status = 422
      {error: outcome.errors.message}
    end
  end

  # DELETE /v1/grids/:name/custom_peers/:peer
  r.delete do
    r.on :peer do |peer|
      outcome = Grids::RemoveCustomPeer.run(
        grid: @grid,
        current_user: current_user,
        peer: peer
      )
      if outcome.success?
        audit_event(r, @grid, @grid, 'remove custom peer')
        response.status = 200
        {}
      else
        response.status = 422
        {error: outcome.errors.message}
      end
    end
  end


  # GET /v1/grids/:id/users
  r.get do
    r.is do
      @users = @grid.users
      render('users/index')
    end
  end
end

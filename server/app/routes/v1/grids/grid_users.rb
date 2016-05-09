require_relative '../../../mutations/grids/assign_user'
V1::GridsApi.route('grid_users') do |r|

  # POST /v1/grids/:name/users
  r.post do
    data = parse_json_body
    user = User.find_by(email: data['email'])
    halt_request(404, {error: 'User not found'}) unless user
    outcome = Grids::AssignUser.run({grid: @grid, current_user: current_user, user: user})
    if outcome.success?
      audit_event(r, @grid, user, 'assign user')
      response.status = 201
      @users = outcome.result
      render('users/index')
    else
      response.status = 422
      {error: outcome.errors.message}
    end
  end

  # DELETE /v1/grids/:name/users/:email
  r.delete do
    r.on :email do |email|
      user = User.find_by(email: email)
      halt_request(404, {error: 'User not found'}) unless user
      outcome = Grids::UnassignUser.run({grid: @grid, current_user: current_user, user: user})
      if outcome.success?
        audit_event(r, @grid, user, 'unassign user')
        response.status = 200
        @users = outcome.result
        render('users/index')
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

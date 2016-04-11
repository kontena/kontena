V1::UsersApi.route('user_roles') do |r|
  r.is do
    r.post do
      params = parse_json_body

      role = Role.find_by(name: params['role'])
      options = {
        current_user: current_user,
        user: @user,
        role: role
      }
      outcome = Users::AddRole.run(options)
      if outcome.success?
        response.status = 201
        render('users/show')
      else
        response.status = 422
        {error: outcome.errors.message}
      end
    end
  end

  r.on ':role' do |role|
    r.delete do
      role = Role.find_by(name: role)
      options = {
        current_user: current_user,
        user: @user,
        role: role
      }
      outcome = Users::RemoveRole.run(options)
      if outcome.success?
        response.status = 200
        @user = outcome.result
        render('users/show')
      else
        response.status = 422
        {error: outcome.errors.message}
      end
    end
  end
end

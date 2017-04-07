describe '/v1/services/:id/event_logs' do

  let(:request_headers) do
    {
        'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token_plain}"
    }
  end

  let! :grid do
    Grid.create!(name: 'terminal-a')
  end

  let(:david) do
    user = User.create!(email: 'david@domain.com', external_id: '123456')
    grid.users << user

    user
  end

  let(:valid_token) do
    AccessToken.create!(user: david, scopes: ['user'])
  end

  let! :redis_service do
    grid.grid_services.create!(
      name: 'redis',
      image_name: 'redis:2.8',
      stateful: true,
      env: ['FOO=BAR']
    )
  end

  describe 'GET' do
    it 'returns service event logs' do
      redis_service.event_logs.create(
        grid: grid,
        msg: 'hello!',
        severity: EventLog::INFO
      )
      get "/v1/services/#{redis_service.to_path}/event_logs", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['logs'].size).to eq(1)
      expect(json_response['logs'].first['message']).to eq('hello!')
    end
  end
end

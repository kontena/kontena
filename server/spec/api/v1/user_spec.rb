
describe '/v1/user' do

  let(:request_headers) do
    {
      'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token_plain}"
    }
  end

  let(:david) do
    user = User.create!(email: 'david@domain.com', external_id: '124567')
    grid = Grid.create!(name: 'Massive Grid')
    grid.users << user

    user
  end

  let(:valid_token) do
    AccessToken.create!(user: david, scopes: ['user'])
  end

  describe 'GET' do
    it 'returns current user' do
      get '/v1/user', nil, request_headers
      expect(last_response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json.keys.sort).to eq(%w(
        id email name roles
      ).sort)
      expect(json['id']).to eq(david.id.to_s)
      expect(json['email']).to eq(david.email)
    end

    it 'returns error without authorization' do
      get '/v1/user'
      expect(response.status).to eq(403)
    end
  end
end

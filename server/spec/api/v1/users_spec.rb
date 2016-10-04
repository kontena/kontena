require_relative '../../spec_helper'

describe '/v1/users' do

  let(:request_headers) do
    {
        'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token_plain}"
    }
  end

  let(:valid_token) do
    AccessToken.create!(user: john, scopes: ['user'])
  end

  let(:master_admin) do
    Role.create!(name: 'master_admin', description: 'Master admin')
  end

  let(:grid_admin) do
    Role.create!(name: 'grid_admin', description: 'Grid admin')
  end

  let(:john) do
    user = User.create!(email: 'john@domain.com', id: '123456')
    user
  end

  let(:jane) do
    user = User.create!(email: 'jane@domain.com', id: '123457')
    user
  end

  describe 'GET /' do
    it 'requires read access to users' do
      get '/v1/users', nil, request_headers
      expect(response.status).to eq(403)
    end

    it 'returns users array' do
      allow(UserAuthorizer).to receive(:readable_by?).with(john).and_return(true)

      get '/v1/users', nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['users']).not_to be_nil
    end

  end

  describe 'POST /' do
    before(:each) do
      allow(UserAuthorizer).to receive(:creatable_by?).with(john).and_return(true)
    end

    it 'creates new user' do
      data = {
        email: 'jane@domain.com',
      }
      expect{
        post '/v1/users', data.to_json, request_headers
        expect(response.status).to eq(201)
        expect(json_response['email']).not_to be_nil
      }.to change{User.count}.by(1)
    end
  end

  describe 'POST /:username/roles' do
    before(:each) do
      allow(RoleAuthorizer).to receive(:assignable_by?).with(john).and_return(true)
    end

    it 'adds user to role' do
      jane
      grid_admin
      data = {
          email: 'jane@domain.com',
          role: 'grid_admin'
      }
      post '/v1/users/jane@domain.com/roles', data.to_json, request_headers

      expect(response.status).to eq(201)
      jane.reload
      expect(jane.roles.include?(grid_admin)).to be_truthy
    end
  end

  describe 'DELETE /:username/roles/:role' do
    before(:each) do
      allow(RoleAuthorizer).to receive(:unassignable_by?).with(john).and_return(true)
    end

    it 'removes user from role' do
      jane.roles << grid_admin
      delete '/v1/users/jane@domain.com/roles/grid_admin', nil, request_headers
      expect(response.status).to eq(200)
      jane.reload
      expect(jane.roles.include?(grid_admin)).to be_falsey
    end
  end

  describe 'DELETE /:username' do
    before(:each) do
      jane
      john
    end

    it 'allows to remove user if master admin' do
      john.roles << master_admin
      expect {
        delete "/v1/users/#{jane.email}", nil, request_headers
        expect(response.status).to eq(200)
      }.to change{ User.count }.by(-1)
    end

    it 'does not allow to remove user if not master admin' do
      delete "/v1/users/#{jane.email}", nil, request_headers
      expect(response.status).to eq(400)
    end

    it 'does not allow to remove self' do
      john.roles << master_admin
      delete "/v1/users/#{john.email}", nil, request_headers
      expect(response.status).to eq(400)
    end

    it 'required authenticated user' do
      delete "/v1/users/#{jane.email}", nil, {}
      expect(response.status).to eq(403)
    end
  end
end

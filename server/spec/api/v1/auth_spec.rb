require_relative '../../spec_helper'

describe '/v1/auth' do

  let(:auth_result) do
    {
      'id' => 'external_id',
      'email' => 'david@domain.com'
    }
  end
  let(:david) do
    User.create!(email: 'david@domain.com', external_id: '123456')
  end

  describe 'POST' do
    before(:each) do
      allow_any_instance_of(AuthService::Client).to receive(:authenticate).and_return(auth_result)
    end

    it 'does auth request' do
      data = {
          username: 'david@domain.com',
          password: 'secret1234',
          grant_type: 'password',
          scope: 'user'
      }

      expect_any_instance_of(AuthService::Client).to receive(:authenticate).once.with(data.stringify_keys).and_return(auth_result)
      post '/v1/auth', data.to_json
    end

    it 'creates admin user if users are not found' do
      data = {
          username: 'david@domain.com',
          password: 'secret1234',
          grant_type: 'password',
          scope: 'user'
      }
      expect {
        post '/v1/auth', data.to_json
      }.to change{ User.count }.by(1)
    end

    it 'updates user data if user is found' do
      data = {
          username: david.email,
          password: 'secret1234',
          grant_type: 'password',
          scope: 'user'
      }
      expect {
        post '/v1/auth', data.to_json
        expect(david.reload.external_id).to eq('external_id')
      }.to change{ User.count }.by(0)
    end

    it 'creates access token' do
      data = {
          username: 'david@domain.com',
          password: 'secret1234',
          grant_type: 'password',
          scope: 'user'
      }
      expect {
        post '/v1/auth', data.to_json
      }.to change{ AccessToken.count }.by(1)
    end

    it 'returns access token and user data' do
      data = {
          username: david.email,
          password: 'secret1234',
          grant_type: 'password',
          scope: 'user'
      }

      post '/v1/auth', data.to_json
      expect(response.status).to eq(201)
      expect(json_response.key?('access_token')).to be_truthy
      expect(json_response['user']['email']).to eq(david.email)
    end

    context 'user is not invited to server' do
      it 'returns error' do
        david
        login_result = {
            'id' => 'external_id',
            'email' => 'jane@domain.com'
        }

        data = {
            username: 'jane@domain.com',
            password: 'secret1234',
            grant_type: 'password',
            scope: 'user'
        }
        expect_any_instance_of(AuthService::Client).to receive(:authenticate).once.with(data.stringify_keys).and_return(login_result)

        expect {
          post '/v1/auth', data.to_json
        }.to change{ User.count }.by(0)
        expect(response.status).to eq(403)
      end
    end
  end
end

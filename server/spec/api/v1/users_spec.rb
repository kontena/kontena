require_relative '../../spec_helper'

describe '/v1/users' do

  let(:request_headers) do
    {
        'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token}"
    }
  end

  let(:valid_token) do
    AccessToken.create!(user: john, scopes: ['user'])
  end

  let(:kontena_user) do
    {
        email: 'john@domain.com',
        id: '12345'
    }
  end

  let(:john) do
    User.create!(email: 'john@domain.com', id: '123456')
  end

  before :each do
    ENV['AUTH_API_URL'] = 'http://test.auth.kontena.io'
  end

  describe 'POST' do

    it 'creates new user' do
      data = {
          email: 'john@domain.com',
      }

      expect{
        post '/v1/users', data.to_json, request_headers
        expect(response.status).to eq(201)

        expect(json_response['email']).not_to be_nil
      }.to change{User.count}.by(1)

    end

  end

  describe 'POST /register' do
    context 'when user is invited' do
      before :each do
        john
      end

      it 'updates user information' do
        data = {
            email: 'john@domain.com',
            password: 'secret1234'
        }
        expect_any_instance_of(AuthService::Client).to receive(:register).once.with(data.stringify_keys).and_return(kontena_user.stringify_keys)

        post '/v1/users/register', data.to_json

        expect(john.reload.external_id).to eq('12345')
        expect(response.status).to eq(200)
        expect(json_response['email']).not_to be_nil

      end

      it 'returns error without valid email' do
        data = {
            email: 'john@domain',
            password: 'secret1234'
        }

        post '/v1/users/register', data.to_json, request_headers
        expect_any_instance_of(AuthService::Client).not_to receive(:register).once.with(data.stringify_keys).and_return(kontena_user.stringify_keys)
        expect(response.status).to eq(422)
        expect(json_response['error']['email']).not_to be_nil
      end

      it 'returns error without password' do
        data = {
            email: 'john@domain.com'
        }

        expect_any_instance_of(AuthService::Client).not_to receive(:register).once.with(data.stringify_keys).and_return(kontena_user.stringify_keys)
        post '/v1/users/register', data.to_json
        expect(response.status).to eq(422)
        expect(json_response['error']['password']).not_to be_nil

      end
    end

    context 'when user is not invited' do
      it 'registers Kontena account' do
        data = {
            email: 'david@domain.com',
            password: 'secret1234'
        }
        john
        expect_any_instance_of(AuthService::Client).to receive(:register).once.with(data.stringify_keys).and_return(kontena_user.stringify_keys)
        post '/v1/users/register', data.to_json
      end

      it 'returns error' do
        data = {
            email: 'david@domain.com',
            password: 'secret1234'
        }
        john
        expect_any_instance_of(AuthService::Client).to receive(:register).and_return(kontena_user.stringify_keys)
        post '/v1/users/register', data.to_json

        expect(response.status).to eq(422)
        expect(json_response['error']['email']).to eq("Kontena account registered successfully, but user is not allowed to use this server.")
      end
    end
  end
end
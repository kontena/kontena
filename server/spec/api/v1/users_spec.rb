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
end
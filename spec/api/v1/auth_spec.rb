require_relative '../../spec_helper'

describe '/v1/auth' do
  let(:david) do
    User.create!(email: 'david@domain.com', external_id: '123456')
  end

  describe 'POST' do
    it 'creates access token' do
      data = {
          username: david.email,
          password: 'secret1234',
          grant_type: 'password',
          scope: 'user'
      }
      expect_any_instance_of(AuthService::Client).to receive(:authenticate).once.with(data.stringify_keys).and_return(david)

      expect {
        post '/v1/auth', data.to_json
        expect(response.status).to eq(201)
      }.to change{ AccessToken.count }.by(1)
    end
  end
end

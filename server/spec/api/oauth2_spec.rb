require_relative '../spec_helper'

describe 'OAuth2 API' do
  let(:david) { User.create(email: 'david@example.com') }
  let(:json_header) { { 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json' } }

  context '/authenticate' do
    describe 'GET /' do
      it 'returns error when AuthProvider is not configured' do
        get '/authenticate'
        expect(response.status).to eq(501)
        expect(response.body).to match(/kontena master auth-provider/)
      end

      it 'returns a redirect when AuthProvider is configured' do
        allow(AuthProvider.instance).to receive(:valid?).and_return(true)
        allow(AuthProvider.instance).to receive(:authorize_url).and_return('http://foo')
        get '/authenticate?redirect_uri=http://localhost:2323'
        expect(response.status).to eq(302)
        expect(response.headers['Location']).to match(/http:\/\/foo/)
      end

      it 'accepts invite code and stores it to auth request state storage' do
        user = User.create(email: 'david@example.com', with_invite: true)
        allow(AuthProvider.instance).to receive(:valid?).and_return(true)
        allow(AuthProvider.instance).to receive(:authorize_url).and_return('http://foo')
        get "/authenticate?redirect_uri=http://localhost:2323&invite_code=#{user.invite_code}"
        expect(AuthorizationRequest.first.user.id).to eq user.id
      end
    end
  end

  context '/oauth2/authorize' do

    let(:token) { AccessToken.create(user: david, scopes: ['user']) }

    context 'response_type = code' do
      it 'returns an authorization code' do
        post(
          '/oauth2/authorize',
          {
            response_type: 'code',
            scope: 'user'
          }.to_json,
          json_header.merge('HTTP_AUTHORIZATION' => "Bearer #{token.token_plain}")
        )
        expect(response.status).to eq(201)
        result = JSON.parse(response.body)
        expect(result['grant_type']).to eq 'authorization_code'
        expect(result['code']).to match /^[a-z0-9]{4,}/
      end
    end

    context 'response_type = token' do
      it 'returns an access token' do
        post(
          '/oauth2/authorize',
          {
            response_type: 'token',
            scope: 'user'
          }.to_json,
          json_header.merge('HTTP_AUTHORIZATION' => "Bearer #{token.token_plain}")
        )

        expect(response.status).to eq(201)
        result = JSON.parse(response.body)
        expect(result['access_token']).to match /^[a-z0-9]{20,}$/
        expect(result['token_type']).to eq "bearer"
      end
    end

    context 'response_type = invite' do
      it 'returns access denied if user is not admin' do
        post(
          '/oauth2/authorize',
          {
            response_type: 'invite',
            email: 'foo@example.com'
          }.to_json,
          json_header.merge('HTTP_AUTHORIZATION' => "Bearer #{token.token_plain}")
        )

        expect(response.status).to eq(403)
      end

      it 'returns an invite if user is admin' do
        david.roles << Role.create!(name: 'master_admin', description: 'foo')
        post(
          '/oauth2/authorize',
          {
            response_type: 'invite',
            email: 'foo@example.com'
          }.to_json,
          json_header.merge('HTTP_AUTHORIZATION' => "Bearer #{token.token_plain}")
        )

        expect(response.status).to eq(201)
        result = JSON.parse(response.body)
        expect(result['invite_code']).to match /^[a-z0-9]{6,}$/
        expect(result['email']).to eq "foo@example.com"
      end
    end
  end

  context '/oauth2/token' do

    before(:each) do 
      allow(AuthProvider.instance).to receive(:seconds_since_last_request).and_return(0)
    end

    context 'grant_type = authorization_code' do
      it 'returns a token in exchange when given a valid code' do
        coded_token = AccessToken.create(user: david, with_code: true, scopes: ['user'])

        post(
          '/oauth2/token',
          {
            grant_type: 'authorization_code',
            code: coded_token.code
          }.to_json,
          json_header
        )

        expect(response.status).to eq(201)
        result = JSON.parse(response.body)
        expect(result['access_token']).to match /^[a-z0-9]{6,}$/
      end

      it 'returns error if code is already used' do
        coded_token = AccessToken.create(user: david, with_code: true, scopes: ['user'])

        post(
          '/oauth2/token',
          {
            grant_type: 'authorization_code',
            code: coded_token.code
          }.to_json,
          json_header
        )

        expect(response.status).to eq(201)

        post(
          '/oauth2/token',
          {
            grant_type: 'authorization_code',
            code: coded_token.code
          }.to_json,
          json_header
        )

        expect(response.status).to eq(404)
      end
    end
    
    context 'grant_type = refresh_token' do
      it 'returns a token in exchange when given a valid refresh token' do
        token = AccessToken.create(user: david, expires_at: Time.now + 7200, scopes: ['user'])

        post(
          '/oauth2/token',
          {
            grant_type: 'refresh_token',
            refresh_token: token.refresh_token_plain
          }.to_json,
          json_header
        )

        expect(response.status).to eq(201)
        result = JSON.parse(response.body)
        expect(result['access_token']).to match /^[a-z0-9]{6,}$/
      end

      it 'returns error if refresh token has been used' do
        token = AccessToken.create(user: david, expires_at: Time.now + 7200, scopes: ['user'])

        post(
          '/oauth2/token',
          {
            grant_type: 'refresh_token',
            refresh_token: token.refresh_token_plain
          }.to_json,
          json_header
        )

        expect(response.status).to eq(201)

        post(
          '/oauth2/token',
          {
            grant_type: 'refresh_token',
            refresh_token: token.refresh_token_plain
          }.to_json,
          json_header
        )

        expect(response.status).to eq(404)
      end

      it 'returns error if refresh token has expired' do
        token = AccessToken.create(user: david, expires_at: Time.now - 7200, scopes: ['user'])

        post(
          '/oauth2/token',
          {
            grant_type: 'refresh_token',
            refresh_token: token.refresh_token_plain
          }.to_json,
          json_header
        )

        expect(response.status).to eq(404)
      end
    end
  end

  context '/cb' do
    it 'returns error if query params include an error' do
      get '/cb?error=not+ok'
      expect(response.status).to eq(502)
    end

    it 'returns error if query params do not include a state' do
      get '/cb?access_token=foo'
      expect(response.status).to eq(400)
    end

    it 'returns error if code can not be exchanged' do
      ar = AuthorizationRequest.create(user: david)
      allow(AuthProvider).to receive(:get_token).and_return(nil)
      get "/cb?code=foo&state=#{ar.state_plain}"
      expect(response.status).to eq(400)
    end

    it 'stores the received token, creates a local access token and redirects when everything is fine' do
      ar = AuthorizationRequest.create(user: david, redirect_uri: 'http://localhost:1234/cb')
      allow(AuthProvider).to receive(:get_token).and_return({
        'access_token' => 'abcd1234',
        'refresh_token' => 'cdef2345',
        'expires_in' => 7200,
        'scope' => 'user:email'
      })
      allow(AuthProvider).to receive(:get_userinfo).and_return({
        id: '12345',
        username: 'testfoo',
        email: 'foofoo@example.com'
      })
      get "/cb?code=foo&state=#{ar.state_plain}"
      expect(response.status).to eq(302)
      local_token = david.access_tokens.where(internal: true).first
      location = response.headers['Location']
      code = location[/code\=([a-z0-9]+)/, 1]
      expect(local_token.code).to eq code
      expect(location).to match /^http:\/\/localhost\:1234\/cb\?/
      david.reload
      expect(david.external_id).to eq '12345'
    end
  end
end



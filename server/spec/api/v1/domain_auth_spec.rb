require_relative '../../spec_helper'

describe '/v1/domain_authorizations' do


  let(:request_headers) do
    {
      'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token_plain}"
    }
  end

  let! :grid do
    grid = Grid.create!(name: 'terminal-a')
  end

  let(:david) do
    user = User.create!(email: 'david@domain.com', external_id: '123456')
    grid.users << user

    user
  end

  let(:john) do
    User.create!(email: 'david@domain.com', external_id: '123456')
  end

  let(:johns_token) do
    AccessToken.create!(user: john, scopes: ['user'])
  end


  let(:valid_token) do
    AccessToken.create!(user: david, scopes: ['user'])
  end

  EXPECTED_KEYS = %w(challenge domain authorization_type challenge_opts).sort

  describe 'GET /' do
    it 'gets domain auth list' do
      GridDomainAuthorization.create!(grid: grid, domain: 'foo1.bar.com')
      GridDomainAuthorization.create!(grid: grid, domain: 'foo2.bar.com')

      get "v1/domain_authorizations/#{grid.name}", nil, request_headers

      expect(response.status).to eq(200)
      expect(json_response['domain_authorizations'].size).to eq(2)
      expect(json_response['domain_authorizations'][0].keys.sort).to eq(EXPECTED_KEYS)
      expect(json_response['domain_authorizations'][1].keys.sort).to eq(EXPECTED_KEYS)
    end
  end

  describe 'GET /:id' do
    it 'gets domain auth' do
      auth = GridDomainAuthorization.create!(grid: grid, domain: 'foo.bar.com')
      get "v1/domain_authorizations/#{grid.name}/foo.bar.com", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response.keys.sort).to eq(EXPECTED_KEYS)
    end

    it 'return 404 for non existing grid' do
      get "/v1/domain_authorizations/foo/bar", nil, request_headers
      expect(response.status).to eq(404)
    end

    it 'return 404 for non existing auth' do
      get "/v1/domain_authorizations/#{grid.name}/bar", nil, request_headers
      expect(response.status).to eq(404)
    end

    it 'requires auth' do
      get "/v1/domain_authorizations/#{grid.name}/foobar", nil
      expect(response.status).to eq(403)
    end

    it 'returns 403 without grid access' do
      # John is not a user in this grid
      get "/v1/domain_authorizations/#{grid.name}", nil, { 'HTTP_AUTHORIZATION' => "Bearer #{johns_token.token_plain}"}
      expect(response.status).to eq(403)
    end
  end

  describe 'PUT' do
    it 'creates new auth request' do
      auth = GridDomainAuthorization.create!(grid: grid, domain: 'foo.bar.com')
      data = {
        domain: 'foo.bar.com',
        auth_type: 'tls-sni-01'
      }
      outcome = double({
        :success? => true,
        :result => auth
      })
      expect(GridCertificates::AuthorizeDomain).to receive(:run).and_return(outcome)

      put "v1/domain_authorizations/#{grid.name}/foo.bar.com", data.to_json, request_headers
      expect(response.status).to eq(200)
      expect(json_response.keys.sort).to eq(EXPECTED_KEYS)
    end

    it 'fails to create new auth request' do
      data = {
        domain: 'foo.bar.com',
        auth_type: 'tls-sni-01'
      }
      outcome = double({
        :success? => false,
        :errors => double({:message => "Error"})
      })
      expect(GridCertificates::AuthorizeDomain).to receive(:run).and_return(outcome)

      put "v1/domain_authorizations/#{grid.name}/foo.bar.com", data.to_json, request_headers
      expect(response.status).to eq(422)

    end
  end

end

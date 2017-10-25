describe '/v1/certificates' do

  let(:request_headers) do
    {
        'HTTP_AUTHORIZATION' => "Bearer #{valid_token.token_plain}"
    }
  end

  let(:grid) do
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

  let(:domain_auth) do
    grid.grid_domain_authorizations.create!(domain: 'kontena.io')
  end

  describe 'GET  grids/<grid/domain_authorizations' do
    it 'returns empty list by default' do
      get "/v1/grids/#{grid.name}/domain_authorizations", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['domain_authorizations'].size).to eq(0)
    end


    it 'returns all domain authorizations' do
      domain_auth
      get "/v1/grids/#{grid.name}/domain_authorizations", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['domain_authorizations'].size).to eq(1)
      expect(json_response['domain_authorizations'][0]['domain']).to eq('kontena.io')
    end

  end

  describe 'DELETE domain_authorizations/<grid>/<domain>' do
    it 'return 404 for missing domain auth' do
      delete "/v1/domain_authorizations/#{grid.name}/foo.bar.com", nil, request_headers
      expect(response.status).to eq(404)
    end

    it 'deletes domain auth' do
      auth = grid.grid_domain_authorizations.create!(domain: 'delete.kontena.io')
      expect {
        delete "/v1/domain_authorizations/#{grid.name}/#{auth.domain}", nil, request_headers
        expect(response.status).to eq(200)
        expect(GridDomainAuthorization.find_by(domain: 'delete.kontena.io')).to be_nil
      }.to change {GridDomainAuthorization.count}.by (-1)

    end
  end

end
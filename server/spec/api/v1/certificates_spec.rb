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

  let!(:certificate) do
    Certificate.create!(
        grid: grid,
        subject: 'kontena.io',
        alt_names: [],
        valid_until: Time.now + 90.days,
        private_key: 'private_key',
        certificate: 'certificate_pem'
      )
  end

  describe 'POST /v1/grids/<grid>/certificates' do
    it 'requests new certificate' do
      outcome = double(
        :success? => true,
        :result => certificate
      )

      expect(GridCertificates::RequestCertificate).to receive(:run).and_return(outcome)
      data = {
        domains: ['kontena.io']
      }
      post "/v1/grids/#{grid.name}/certificates", data.to_json, request_headers
      expect(response.status).to eq(201), response.body
      expect(json_response['subject']).to eq('kontena.io')
    end

    it 'fails in requesting new certificate' do
      outcome = double(
        :success? => false,
        :result => certificate,
        :errors => double(:message => 'kaboom')
      )
      expect(GridCertificates::RequestCertificate).to receive(:run).and_return(outcome)
      post "/v1/grids/#{grid.name}/certificates", {}, request_headers
      expect(response.status).to eq(422), response.body
      expect(json_response['error']).to eq('kaboom')
    end
  end

  describe 'GET /v1/grids/<grid>/certificates' do
    it 'gets all certs' do
      get "/v1/grids/#{grid.name}/certificates", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['certificates'].size).to eq(1)
      expect(json_response['certificates'][0]['subject']).to eq('kontena.io')
    end
  end

  describe 'GET /v1/certificates/<grid>/<subject>' do
    it 'gets a certificate' do
      get "/v1/certificates/#{grid.name}/kontena.io", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['subject']).to eq('kontena.io')
      expect(json_response['id']).to eq("#{grid.name}/kontena.io")
    end

    it '404 for non-existing cert' do
      get "/v1/certificates/#{grid.name}/foobar.io", nil, request_headers
      expect(response.status).to eq(404)
    end
  end

  describe 'DELETE /v1/certificates/<grid>/<subject>' do
    it 'deletes certificate' do
      expect {
        delete "/v1/certificates/#{grid.name}/kontena.io", nil, request_headers
        expect(response.status).to eq(200)
      }.to change{Certificate.count}.by (-1)

    end

    it 'fails deleting certificate as it\'s in use' do
      GridService.create!(grid: grid, name: 'redis', image_name: 'redis', certificates: [GridServiceCertificate.new(subject: 'kontena.io', name: 'SSL_CERT')])
      expect {
        delete "/v1/certificates/#{grid.name}/kontena.io", nil, request_headers
        expect(response.status).to eq(422)
        expect(json_response['error']['certificate']).to match(/Certificate still in use/)
      }.not_to change{Certificate.count}

    end

    it 'return 404 for missing cert' do
      delete "/v1/certificates/#{grid.name}/foobar.io", nil, request_headers
      expect(response.status).to eq(404)
      expect(json_response['error']).to eq('Not found')
    end
  end


end
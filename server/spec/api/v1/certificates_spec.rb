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

  let(:ca_pem) { '-----BEGIN CERTIFICATE-----
MIIBYzCCAQ2gAwIBAgIJAIpNg6jylBQkMA0GCSqGSIb3DQEBCwUAMA0xCzAJBgNV
BAMMAkNBMB4XDTE3MTAzMTE3MDEyN1oXDTE4MTAzMTE3MDEyN1owDTELMAkGA1UE
AwwCQ0EwXDANBgkqhkiG9w0BAQEFAANLADBIAkEAz/Ee36KUY7l0tRFREO/XOSoO
Xqyv48Jcvz0TnV7d+n3yapzCZfvDtX0qMpdZqd4Gr7v2Zgr64PJJNELfSE/vMQID
AQABo1AwTjAdBgNVHQ4EFgQUcLvPScr8TZMmeiGGtFQecMBrt+IwHwYDVR0jBBgw
FoAUcLvPScr8TZMmeiGGtFQecMBrt+IwDAYDVR0TBAUwAwEB/zANBgkqhkiG9w0B
AQsFAANBAGjroEv8WBLeIbGbSDM6RMVHQjt8V5Pwd/RPI7pusWGsaJbOVXCwQSsd
wpUzwKt2lbtAZFmLIIJ53Pv0PZsgC6Q=
-----END CERTIFICATE-----
' }

  let(:cert_pem) {
    '-----BEGIN CERTIFICATE-----
MIIBBTCBsAIBAjANBgkqhkiG9w0BAQsFADANMQswCQYDVQQDDAJDQTAeFw0xNzEw
MzExNzA2MzJaFw0xNzExMzAxNzA2MzJaMA8xDTALBgNVBAMMBHRlc3QwXDANBgkq
hkiG9w0BAQEFAANLADBIAkEA+jOxPABMu7Kp4lfrlGXWm+kQWIj4FSi5pczK/ReE
w1Gxhq49CEt3bIC3Li8slJU4H1WZbhbz8VWyEUsmaYEfiQIDAQABMA0GCSqGSIb3
DQEBCwUAA0EAIHbczx/kmb/ji/5kDtAUldbicApY9vl75JbPxnAfU5yqyZjhsFiF
uH6nBTUEAXS4Ic89vJ+J9e14hXh7YLzq1w==
-----END CERTIFICATE-----
' }

  let(:key_pem) { '-----BEGIN PRIVATE KEY-----
MIIBVgIBADANBgkqhkiG9w0BAQEFAASCAUAwggE8AgEAAkEA+jOxPABMu7Kp4lfr
lGXWm+kQWIj4FSi5pczK/ReEw1Gxhq49CEt3bIC3Li8slJU4H1WZbhbz8VWyEUsm
aYEfiQIDAQABAkBb0uTU1HdU23klrIa067sbdSmelIYXnd6kTsigoiUDWRo9mccV
kPx4bL+L9bL2BX64+Sqjch2+EUYYqQSQLMzRAiEA/fpz9nR5feWi75URhS1oHi/0
vpYxvQlTyt6LNBG6LxsCIQD8MYs+tUhwCfuKHPSfqE9oizOwAcfTUp/PVgLGhWcC
KwIhAN3AQGGuHqmqx5GRwSNbmu3Ih1Okhbb8ntmhZz9GPx6DAiEAjPfApt+8Suw5
j30Z+/if0ock8Dg+k1A3BjVEveUprBsCIQCjel8oZuN/3zatvWMCgCQboYoQjw9M
U3GffGoMbo0kTw==
-----END PRIVATE KEY-----
' }

  let!(:certificate) do
    Certificate.create!(
        grid: grid,
        subject: 'kontena.io',
        alt_names: [],
        valid_until: Time.now + 90.days,
        private_key: key_pem,
        certificate: cert_pem,
        chain: ca_pem,
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

      data = {
        domains: ['kontena.io']
      }
      post "/v1/grids/#{grid.name}/certificates", data.to_json, request_headers
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

  describe 'GET /v1/certificates/<grid>/<subject>/export' do
    it 'exports a certificate' do
      get "/v1/certificates/#{grid.name}/kontena.io/export", nil, request_headers
      expect(response.status).to eq(200)
      expect(json_response['id']).to eq("#{grid.name}/kontena.io")
      expect(json_response['subject']).to eq('kontena.io')
      expect(json_response['certificate']).to eq(cert_pem)
      expect(json_response['chain']).to eq(ca_pem)
      expect(json_response['private_key']).to eq(key_pem)
    end
  end

  describe 'PUT /v1/certificates/<grid>/<subject>' do
    it 'imports certificate' do
      data = {
        certificate: cert_pem,
        chain: [ca_pem],
        private_key: key_pem,
      }
      put "/v1/certificates/#{grid.name}/test", data.to_json, request_headers
      expect(response.status).to eq(201), response.body
      expect(json_response['subject']).to eq('test')
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

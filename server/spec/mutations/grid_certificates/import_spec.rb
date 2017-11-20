describe GridCertificates::Import do
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

  let(:cert_pem) { '-----BEGIN CERTIFICATE-----
MIIBJzCB0qADAgECAgEFMA0GCSqGSIb3DQEBCwUAMA0xCzAJBgNVBAMMAkNBMB4X
DTE3MTAzMTE5MzA1MloXDTE3MTEzMDE5MzA1MlowDzENMAsGA1UEAwwEdGVzdDBc
MA0GCSqGSIb3DQEBAQUAA0sAMEgCQQD6M7E8AEy7sqniV+uUZdab6RBYiPgVKLml
zMr9F4TDUbGGrj0IS3dsgLcuLyyUlTgfVZluFvPxVbIRSyZpgR+JAgMBAAGjGzAZ
MBcGA1UdEQQQMA6CBHRlc3SCBnRlc3QtMTANBgkqhkiG9w0BAQsFAANBAGVbIF1b
n4U4FXPFU5/H0eOVZSC2ivbDa/RBArf4R7ib9qdH4rRQif7Gn6Lih4tuR6zMFBd/
M1Qkkjz7IeynUtw=
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

  let(:key_rsa_pem) { '-----BEGIN RSA PRIVATE KEY-----
MIIBPAIBAAJBAPozsTwATLuyqeJX65Rl1pvpEFiI+BUouaXMyv0XhMNRsYauPQhL
d2yAty4vLJSVOB9VmW4W8/FVshFLJmmBH4kCAwEAAQJAW9Lk1NR3VNt5JayGtOu7
G3UpnpSGF53epE7IoKIlA1kaPZnHFZD8eGy/i/Wy9gV+uPkqo3IdvhFGGKkEkCzM
0QIhAP36c/Z0eX3lou+VEYUtaB4v9L6WMb0JU8reizQRui8bAiEA/DGLPrVIcAn7
ihz0n6hPaIszsAHH01Kfz1YCxoVnAisCIQDdwEBhrh6pqseRkcEjW5rtyIdTpIW2
/J7ZoWc/Rj8egwIhAIz3wKbfvErsOY99Gfv4n9KHJPA4PpNQNwY1RL3lKawbAiEA
o3pfKGbjf982rb1jAoAkG6GKEI8PTFNxn3xqDG6NJE8=
-----END RSA PRIVATE KEY-----
'}

  let(:subject_param) { 'test' }

  let(:subject) { described_class.new(grid: grid,
    subject: subject_param,
    certificate: cert_pem,
    chain: [ca_pem],
    private_key: key_pem,
  ) }

  let(:grid) {
    Grid.create!(name: 'test-grid')
  }

  describe '#execute' do
    it 'imports the certificate' do
      cert = nil

      expect {
        cert = subject.execute
      }.to change {grid.certificates.count}.by (1)

      expect(cert.subject).to eq('test')
      expect(cert.valid_until).to eq(DateTime.parse('Nov 30 19:30:52 2017 GMT'))
      expect(cert.alt_names).to eq ['test-1']
      expect(cert.private_key).to eq(key_rsa_pem) # XXX: converts from PKCS#8 -> PKCS#1 format
      expect(cert.certificate).to eq(cert_pem)
      expect(cert.chain).to eq(ca_pem)

      expect(grid.certificates.find_by(subject: 'test')).to eq cert
    end
  end

  context 'with the wrong subject name' do
    let(:subject_param) { 'example' }

    it 'fails validation' do
      expect(outcome = subject.run).to_not be_success

      expect(outcome.errors.message).to eq 'subject' => "Certificate subject 'test' does not match expected subject 'example'"
    end
  end

  context 'with a pre-existing certificate' do
    let!(:certificate) { Certificate.create!(grid: grid, subject: 'test', valid_until: Time.now) }

    it 'updates certificate' do
      outcome = nil

      expect {
        outcome = subject.run
      }.to change{certificate.reload.certificate}

      expect(outcome).to be_success
    end
  end
end

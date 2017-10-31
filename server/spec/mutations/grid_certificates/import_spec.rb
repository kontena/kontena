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

  let(:subject) { described_class.new(grid: grid,
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
      expect(cert.valid_until).to eq(DateTime.parse('Nov 30 17:06:32 2017 GMT'))
      expect(cert.alt_names).to be_empty
      expect(cert.private_key).to eq(key_rsa_pem) # XXX: converts from PKCS#8 -> PKCS#1 format
      expect(cert.certificate).to eq(cert_pem)
      expect(cert.chain).to eq(ca_pem)
    end
  end
end

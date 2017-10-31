require 'kontena/cli/certificate/export_command'

describe Kontena::Cli::Certificate::ExportCommand do
  include ClientHelpers
  include OutputHelpers

  let(:subject) { described_class.new("kontena") }

  let(:certificate) {
    {
      'id' => 'test/test.example.com',
      'subject' => 'test.example.com',
      'certificate_pem' => '-----BEGIN CERTIFICATE-----
MIIBBTCBsAIBAjANBgkqhkiG9w0BAQsFADANMQswCQYDVQQDDAJDQTAeFw0xNzEw
MzExNzA2MzJaFw0xNzExMzAxNzA2MzJaMA8xDTALBgNVBAMMBHRlc3QwXDANBgkq
hkiG9w0BAQEFAANLADBIAkEA+jOxPABMu7Kp4lfrlGXWm+kQWIj4FSi5pczK/ReE
w1Gxhq49CEt3bIC3Li8slJU4H1WZbhbz8VWyEUsmaYEfiQIDAQABMA0GCSqGSIb3
DQEBCwUAA0EAIHbczx/kmb/ji/5kDtAUldbicApY9vl75JbPxnAfU5yqyZjhsFiF
uH6nBTUEAXS4Ic89vJ+J9e14hXh7YLzq1w==
-----END CERTIFICATE-----
',
      'chain_pem' => '-----BEGIN CERTIFICATE-----
MIIBYzCCAQ2gAwIBAgIJAIpNg6jylBQkMA0GCSqGSIb3DQEBCwUAMA0xCzAJBgNV
BAMMAkNBMB4XDTE3MTAzMTE3MDEyN1oXDTE4MTAzMTE3MDEyN1owDTELMAkGA1UE
AwwCQ0EwXDANBgkqhkiG9w0BAQEFAANLADBIAkEAz/Ee36KUY7l0tRFREO/XOSoO
Xqyv48Jcvz0TnV7d+n3yapzCZfvDtX0qMpdZqd4Gr7v2Zgr64PJJNELfSE/vMQID
AQABo1AwTjAdBgNVHQ4EFgQUcLvPScr8TZMmeiGGtFQecMBrt+IwHwYDVR0jBBgw
FoAUcLvPScr8TZMmeiGGtFQecMBrt+IwDAYDVR0TBAUwAwEB/zANBgkqhkiG9w0B
AQsFAANBAGjroEv8WBLeIbGbSDM6RMVHQjt8V5Pwd/RPI7pusWGsaJbOVXCwQSsd
wpUzwKt2lbtAZFmLIIJ53Pv0PZsgC6Q=
-----END CERTIFICATE-----
',
      'private_key_pem' => '-----BEGIN PRIVATE KEY-----
MIIBVgIBADANBgkqhkiG9w0BAQEFAASCAUAwggE8AgEAAkEA+jOxPABMu7Kp4lfr
lGXWm+kQWIj4FSi5pczK/ReEw1Gxhq49CEt3bIC3Li8slJU4H1WZbhbz8VWyEUsm
aYEfiQIDAQABAkBb0uTU1HdU23klrIa067sbdSmelIYXnd6kTsigoiUDWRo9mccV
kPx4bL+L9bL2BX64+Sqjch2+EUYYqQSQLMzRAiEA/fpz9nR5feWi75URhS1oHi/0
vpYxvQlTyt6LNBG6LxsCIQD8MYs+tUhwCfuKHPSfqE9oizOwAcfTUp/PVgLGhWcC
KwIhAN3AQGGuHqmqx5GRwSNbmu3Ih1Okhbb8ntmhZz9GPx6DAiEAjPfApt+8Suw5
j30Z+/if0ock8Dg+k1A3BjVEveUprBsCIQCjel8oZuN/3zatvWMCgCQboYoQjw9M
U3GffGoMbo0kTw==
-----END PRIVATE KEY-----
',
    }
  }

  before do
    allow(client).to receive(:get).with('certificates/test-grid/test.example.com/export').and_return(certificate)
  end

  it "outputs the cert bundle" do
    expect{subject.run(['test.example.com'])}.to output('-----BEGIN CERTIFICATE-----
MIIBBTCBsAIBAjANBgkqhkiG9w0BAQsFADANMQswCQYDVQQDDAJDQTAeFw0xNzEw
MzExNzA2MzJaFw0xNzExMzAxNzA2MzJaMA8xDTALBgNVBAMMBHRlc3QwXDANBgkq
hkiG9w0BAQEFAANLADBIAkEA+jOxPABMu7Kp4lfrlGXWm+kQWIj4FSi5pczK/ReE
w1Gxhq49CEt3bIC3Li8slJU4H1WZbhbz8VWyEUsmaYEfiQIDAQABMA0GCSqGSIb3
DQEBCwUAA0EAIHbczx/kmb/ji/5kDtAUldbicApY9vl75JbPxnAfU5yqyZjhsFiF
uH6nBTUEAXS4Ic89vJ+J9e14hXh7YLzq1w==
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIBYzCCAQ2gAwIBAgIJAIpNg6jylBQkMA0GCSqGSIb3DQEBCwUAMA0xCzAJBgNV
BAMMAkNBMB4XDTE3MTAzMTE3MDEyN1oXDTE4MTAzMTE3MDEyN1owDTELMAkGA1UE
AwwCQ0EwXDANBgkqhkiG9w0BAQEFAANLADBIAkEAz/Ee36KUY7l0tRFREO/XOSoO
Xqyv48Jcvz0TnV7d+n3yapzCZfvDtX0qMpdZqd4Gr7v2Zgr64PJJNELfSE/vMQID
AQABo1AwTjAdBgNVHQ4EFgQUcLvPScr8TZMmeiGGtFQecMBrt+IwHwYDVR0jBBgw
FoAUcLvPScr8TZMmeiGGtFQecMBrt+IwDAYDVR0TBAUwAwEB/zANBgkqhkiG9w0B
AQsFAANBAGjroEv8WBLeIbGbSDM6RMVHQjt8V5Pwd/RPI7pusWGsaJbOVXCwQSsd
wpUzwKt2lbtAZFmLIIJ53Pv0PZsgC6Q=
-----END CERTIFICATE-----
-----BEGIN PRIVATE KEY-----
MIIBVgIBADANBgkqhkiG9w0BAQEFAASCAUAwggE8AgEAAkEA+jOxPABMu7Kp4lfr
lGXWm+kQWIj4FSi5pczK/ReEw1Gxhq49CEt3bIC3Li8slJU4H1WZbhbz8VWyEUsm
aYEfiQIDAQABAkBb0uTU1HdU23klrIa067sbdSmelIYXnd6kTsigoiUDWRo9mccV
kPx4bL+L9bL2BX64+Sqjch2+EUYYqQSQLMzRAiEA/fpz9nR5feWi75URhS1oHi/0
vpYxvQlTyt6LNBG6LxsCIQD8MYs+tUhwCfuKHPSfqE9oizOwAcfTUp/PVgLGhWcC
KwIhAN3AQGGuHqmqx5GRwSNbmu3Ih1Okhbb8ntmhZz9GPx6DAiEAjPfApt+8Suw5
j30Z+/if0ock8Dg+k1A3BjVEveUprBsCIQCjel8oZuN/3zatvWMCgCQboYoQjw9M
U3GffGoMbo0kTw==
-----END PRIVATE KEY-----
').to_stdout
  end
end

describe GridDomainAuthorizations::Authorize do
  let(:grid) { Grid.create!(name: 'test-grid') }

  let!(:le_private_key) { GridSecret.create!(grid: grid, name: 'LE_PRIVATE_KEY', value: 'LE_PRIVATE_KEY') }

  describe '#validate' do
    context 'without a valid LE registration' do
      before do
        le_private_key.destroy
      end

      it 'fails validation' do
        outcome = described_class.validate(grid: grid, domain: 'example.com')

        expect(outcome).not_to be_success
        expect(outcome.errors.message).to eq 'le_registration' => "Let's Encrypt registration missing"
      end
    end

    describe 'authorization_type=dns-01' do
      it 'fails with a linked service' do
        outcome = described_class.validate(grid: grid, domain: 'example.com',
          authorization_type: 'dns-01',
          linked_service: 'test/test',
        )

        expect(outcome).not_to be_success
        expect(outcome.errors.message).to eq 'linked_service' => "Service link cannot be given for the dns-01 authorization type"
      end
    end

    describe 'authorization_type=tls-sni-01' do
      it 'fails without a linked service' do
        outcome = described_class.validate(grid: grid, domain: 'example.com',
          authorization_type: 'tls-sni-01',
        )

        expect(outcome).not_to be_success
        expect(outcome.errors.message).to eq 'linked_service' => "Service link needs to be given for the tls-sni-01 authorization type"
      end

      it 'fails with a non-existing linked service' do
        outcome = described_class.validate(grid: grid, domain: 'example.com',
          authorization_type: 'tls-sni-01',
          linked_service: 'non/existing',
        )

        expect(outcome).not_to be_success
        expect(outcome.errors.message).to eq 'linked_service' => "Linked service not found: non/existing"
      end

      context 'for a linked service without exposed ports' do
        let!(:grid_service) { GridService.create(grid: grid, name: 'web', image_name: 'web:latest') }

        it 'fails validation with missing port 443' do
          outcome = described_class.validate(grid: grid, domain: 'example.com',
            authorization_type: 'tls-sni-01',
            linked_service: 'null/web',
          )

          expect(outcome).not_to be_success
          expect(outcome.errors.message).to eq 'linked_service' => "Linked service does not have port 443 open"
        end
      end

      context 'for a linked service with network_mode=host' do
        let!(:grid_service) { GridService.create(grid: grid, name: 'web', image_name: 'web:latest',
          net: 'host',
        ) }

        it 'passes validation' do
          outcome = described_class.validate(grid: grid, domain: 'example.com',
            authorization_type: 'tls-sni-01',
            linked_service: 'null/web',
          )

          expect(outcome).to be_success
        end
      end

      context 'for a linked service exposing port 443' do
        let!(:grid_service) { GridService.create(grid: grid, name: 'web', image_name: 'web:latest',
          ports: [ { 'node_port' => 443 } ],
        ) }

        it 'passes validation' do
          outcome = described_class.validate(grid: grid, domain: 'example.com',
            authorization_type: 'tls-sni-01',
            linked_service: 'null/web',
          )

          expect(outcome).to be_success
        end
      end
    end

    describe 'authorization_type=http-01' do
      it 'fails without a linked service' do
        outcome = described_class.validate(grid: grid, domain: 'example.com',
          authorization_type: 'http-01',
        )

        expect(outcome).not_to be_success
        expect(outcome.errors.message).to eq 'linked_service' => "Service link needs to be given for the http-01 authorization type"
      end

      context 'for a linked service without exposed ports' do
        let!(:grid_service) { GridService.create(grid: grid, name: 'web', image_name: 'web:latest') }

        it 'fails validation with missing port 80' do
          outcome = described_class.validate(grid: grid, domain: 'example.com',
            authorization_type: 'http-01',
            linked_service: 'null/web',
          )

          expect(outcome).not_to be_success
          expect(outcome.errors.message).to eq 'linked_service' => "Linked service does not have port 80 open"
        end
      end

      context 'for a linked service with network_mode=host' do
        let!(:grid_service) { GridService.create(grid: grid, name: 'web', image_name: 'web:latest',
          net: 'host',
        ) }

        it 'passes validation' do
          outcome = described_class.validate(grid: grid, domain: 'example.com',
            authorization_type: 'http-01',
            linked_service: 'null/web',
          )

          expect(outcome).to be_success
        end
      end

      context 'for a linked service exposing port 80' do
        let!(:grid_service) { GridService.create(grid: grid, name: 'web', image_name: 'web:latest',
          ports: [ { 'node_port' => 80 } ],
        ) }

        it 'passes validation' do
          outcome = described_class.validate(grid: grid, domain: 'example.com',
            authorization_type: 'http-01',
            linked_service: 'null/web',
          )

          expect(outcome).to be_success
        end
      end
    end
  end

  let(:acme_client) { instance_double(Acme::Client) }

  before(:each) do
    allow(subject).to receive(:acme_client).and_return(acme_client)
  end

  let(:acme_authorization) { double(
    status: 'pending',
    expires: Time.now + 300,
    dns01: double(
      record_name: '_acme-challenge',
      record_type: 'TXT',
      record_content: '123456789',
      to_h: {}
    )
  ) }

  describe 'authorization_type=dns-01' do
    subject { described_class.new(grid: grid, domain: 'example.com',
      authorization_type: 'dns-01',
    ) }

    it 'requests domain authorization and creates model' do
      expect(acme_client).to receive(:authorize).with(domain: 'example.com').and_return(acme_authorization)

      expect(outcome = subject.run).to be_success

      authz = GridDomainAuthorization.find_by(domain: 'example.com')

      expect(authz).to_not be_nil
      expect(authz).to eq outcome.result
      expect(authz.domain).to eq 'example.com'
      expect(authz.authorization_type).to eq 'dns-01'
      expect(authz.challenge_opts).to eq(
        'record_name' => '_acme-challenge',
        'record_type' => 'TXT',
        'record_content' => '123456789',
      )
    end

    it 'fails if LE does not offer a dns-01 challenge' do
      expect(acme_client).to receive(:authorize).with(domain: 'example.com').and_return(double(dns01: nil))

      expect {
        outcome = subject.run

        expect(outcome).to_not be_success
        expect(outcome.errors.message).to eq 'challenge' => "LE did not offer any dns-01 challenge"
      }.not_to change{GridDomainAuthorization.count}
    end

    context 'with an existing authz' do
      let!(:authz) {
        challenge_opts = {
          'record_name' => '_acme-challenge',
          'record_content' => '1234567890'
        }
        GridDomainAuthorization.create!(grid: grid, domain: 'example.com', challenge: {}, challenge_opts: challenge_opts)
      }

      it 'replaces the authz' do
        expect(acme_client).to receive(:authorize).with(domain: 'example.com').and_return(acme_authorization)

        expect {
          expect(outcome = subject.run).to be_success
        }.to change{GridDomainAuthorization.find_by(domain: 'example.com')}.from(authz)
      end
    end
  end

  describe 'authorization_type=http-01' do
    let(:challenge_token) { 'LoqXcYV8q5ONbJQxbmR7SCTNo3tiAXDfowyjxAjEuX0' }
    let(:challenge_content) { 'LoqXcYV8q5ONbJQxbmR7SCTNo3tiAXDfowyjxAjEuX0.9jg46WB3rR_AHD-EBXdN7cBkH1WOu0tA3M9fm21mqTI' }
    let(:expires_at) { Time.now + 300 }
    let(:acme_authorization) { double(
      status: 'pending',
      expires: expires_at,
      http01: double(
        token: challenge_token,
        file_content: challenge_content,
        to_h: {}
      ),
    ) }

    context 'with a linked service' do
      let(:linked_service) { GridService.create(grid: grid, name: 'lb', image_name: 'kontena/lb:latest',
        ports: [ { 'node_port' => 80 } ],
      ) }

      subject {
        linked_service
        described_class.new(grid: grid, domain: 'example.com',
          authorization_type: 'http-01',
          linked_service: 'null/lb',
        )
      }

      it 'requests domain authorization and creates model' do
        expect(acme_client).to receive(:authorize).with(domain: 'example.com').and_return(acme_authorization)

        expect(outcome = subject.run).to be_success

        authz = GridDomainAuthorization.find_by(domain: 'example.com')

        expect(authz).to_not be_nil
        expect(authz).to eq outcome.result
        expect(authz.domain).to eq 'example.com'
        expect(authz.authorization_type).to eq 'http-01'
        expect(authz.challenge_opts).to eq(
          'token' => challenge_token,
          'content' => challenge_content,
        )
      end

      it 'fails if LE does not offer a http-01 challenge' do
        expect(acme_client).to receive(:authorize).with(domain: 'example.com').and_return(double(http01: nil))

        expect {
          outcome = subject.run

          expect(outcome).to_not be_success
          expect(outcome.errors.message).to eq 'challenge' => "LE did not offer any http-01 challenge"
        }.not_to change{GridDomainAuthorization.count}
      end
    end
  end

  describe 'authorization_type=tls-sni-01' do
    let(:challenge_cert) {
<<-EOF
-----BEGIN CERTIFICATE-----
MIIC0zCCAbsCAQAwDQYJKoZIhvcNAQELBQAwADAeFw0xODAxMDIxMjEwMjJaFw0x
ODAyMDExMzEwMjJaMAAwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDa
bL/cF8pwn2YmiCmfkQ4xlLdpAsa/PZ2grpIpqC4yQ/ixqSgmz51IJzefeiBIXWPg
/eweXj0tdiFPh/8fuRFIHd2/yXRic97HZQgjgpM/OOSaf+4epCq3n3MFRkIGMhKB
EsoIlwWKCDehyJ9rp3DhaNbr51OwrMiPztkgFqDwVAK6cbqdYqVRa3BOOjwXFnb1
G8QidoX054qYYMoH969j5CG20VdOMYrxOWrghTQjP/3IJGXrU8nQdL3khjULExt0
G/g0L1HZ1JYD4ZOR3Uq3cClJwxzavkKKoebkwnjxp+J/brJrp21ieuM0U0+lxn+s
fKDmyGrqlSDXI2H2SWhjAgMBAAGjXTBbMFkGA1UdEQRSMFCCTmQxMzkyNGFiMjY1
MjJhMjUyNjA5MjRlZTg3MTdlNjU5LmM2YjM5MTEyNjI4NzgwNzQzODk5MzJiYWI0
ZGU5ZjdmLmFjbWUuaW52YWxpZDANBgkqhkiG9w0BAQsFAAOCAQEAyUyYSLGZtTRI
SiC/111YCxDoypJctkEHkcB/6eKRzztT8TgHuxMYsPMJ2TgJv8Z722PxungKMFGD
e44i+4dvLd90EUBcQa0ugcaRxdOMFl6aLdatSHHH5hsixQQwTLOJjoSyrq2b92GD
jrvH96AGYKwHolwvQmYBje03Jo0Uf5hZdxxxd9wfdxQaZ89UL2wVJHO4UTEFLrBp
4HwQaXXKyhJMB6MCfsSKl+rYtmnmqlbqnxDRYASlgI6dTx6Fj+Ydc+mSdrOqBU+l
hSUYw4x4tAiTvRj+z1Az4xT08i0ke1HCF4ob3wl67css15bxnSriUnGNJE27Hv95
OEhqU1212A==
-----END CERTIFICATE-----
EOF
    }
    let(:challenge_key) {
<<-EOF
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA2my/3BfKcJ9mJogpn5EOMZS3aQLGvz2doK6SKaguMkP4sako
Js+dSCc3n3ogSF1j4P3sHl49LXYhT4f/H7kRSB3dv8l0YnPex2UII4KTPzjkmn/u
HqQqt59zBUZCBjISgRLKCJcFigg3ocifa6dw4WjW6+dTsKzIj87ZIBag8FQCunG6
nWKlUWtwTjo8FxZ29RvEInaF9OeKmGDKB/evY+QhttFXTjGK8Tlq4IU0Iz/9yCRl
61PJ0HS95IY1CxMbdBv4NC9R2dSWA+GTkd1Kt3ApScMc2r5CiqHm5MJ48afif26y
a6dtYnrjNFNPpcZ/rHyg5shq6pUg1yNh9kloYwIDAQABAoIBACzkuTJleWhYeshk
qBlx2Pb72A6vUWYxJdrGxqflN0mBivYJDIWdmnggB2Cx2zzEZSjzR7qeJ/jWFNah
3yAIC7NE4DTxFQi/RAS7kUarKdSOvv26WZjWqSkAjsWAwUVAuWjqEbheQfcy5SxN
bebUjXDm+XWXIC5p9PcJzrq3q/B5Ep2lksKyUIOHk8lNtjcVyF/x6oFJxMn1rRuN
aD52ZlptwElYO7olxjte6oUZkLD1RdX6JcBHYzrwrTYbf7J14Iejxq2mcuhRG8+C
PTLkjOnW25KYcoZdqIbd8aNfB+R6ZGg4mce6nsCKJtojX72W+gAN/xaqzSG5LKOG
kZQa7TECgYEA+AdFSlNNHsCnzjJAyH/4Bnr8smiC6a4OB14UN/qYRNiaRhtsyWck
OJ8TH9DLrRXDaYtjuckjoYhiwE2YCFj9iB7ybfS6weTpAJUKmVe68t9tHH8Ik+1x
Ntc739rrkyai9pGOkwF7tSWGFLJUXbe+O8fSV43ICwfMOhWCE6uApA8CgYEA4XHn
+WNDuSkIN4ylkl0Tuw8ApwIgzahMqe/dbpdM2gNJC8iKDNmbF9bSccF1rtbxQYDA
59b7Xsg+O1dwhBUSSa1+G2uj1i90uQl3EFPfOHCXCR2D0Q4jcgPIFa953LfH0nNZ
TME+tzpQ/lHBovbC0/iVK0TR7f8sNzYIce7dkm0CgYB46qJ/H6lDSs0EGz+1/50d
G6xCFe1smuw/7z+QIt1FAwwDDa+1aFEiQXsDUblaAngn5kqR8lsqjuEFu05ZE3lW
eS/bJyo9CKoHHKH0K+76JK5+6/d0lpdRExEfiwy5ymY8Kq4FQP3cTBTX1jCHF+Lo
JfyHrplNt1l7H60whbXLRQKBgQDP36TDCmluuMvv1Iryy0ofKDU0yTyQBQgzhY3K
pE3jlDXtXIsWUCu2rok7BORLQ7wO5vZ4j30Wp1LiiryfvYIwV325MOZP31AkMfsM
HhnsQ7ywVfuubvf18FC01ilqgDcK8Ps9T85RSr9V0PLYHeoFY+e/juR3K9uMSRE+
ZL7/fQKBgEmJTVD8INcOUUxCt/zHxdLNVTPWwOLXRveScI/F40FA/pt+pg5Uh3gR
wNLSkr804nBFs7NXHhZdEgK9tlzf3iEJqu+L2Kt1KKrVx4QLD2qZs+EGNoIuKCeq
h/uuErYzGIWNm+YhveiZKaCQN8mhbinqdop1GZ54oFw0qEH1kF/P
-----END RSA PRIVATE KEY-----
EOF
    }
    let(:expires_at) { Time.now + 300 }
    let(:acme_authorization) { double(
      status: 'pending',
      expires: expires_at,
      tls_sni01: double(
        certificate: double(to_pem: challenge_cert),
        private_key: double(to_pem: challenge_key),
        to_h: {}
      ),
    ) }

    context 'with a linked service' do
      let(:linked_service) { GridService.create(grid: grid, name: 'lb', image_name: 'kontena/lb:latest',
        ports: [ { 'node_port' => 443 } ],
      ) }

      subject {
        linked_service
        described_class.new(grid: grid, domain: 'example.com',
          authorization_type: 'tls-sni-01',
          linked_service: 'null/lb',
        )
      }

      it 'requests domain authorization and creates model' do
        expect(acme_client).to receive(:authorize).with(domain: 'example.com').and_return(acme_authorization)

        expect(outcome = subject.run).to be_success

        authz = GridDomainAuthorization.find_by(domain: 'example.com')

        expect(authz).to_not be_nil
        expect(authz).to eq outcome.result
        expect(authz.domain).to eq 'example.com'
        expect(authz.authorization_type).to eq 'tls-sni-01'
        expect(authz.tls_sni_certificate).to eq challenge_cert + challenge_key
        expect(authz.grid_service).to eq linked_service
        expect(authz.grid_service_deploy).not_to be_nil
        expect(authz.expires_at).to be > Time.now

        expect(authz).to be_pending
        expect(authz).to be_deployable
        expect(authz.status).to eq :deploying
      end

      it 'fails if LE does not offer a dns-01 challenge' do
        expect(acme_client).to receive(:authorize).with(domain: 'example.com').and_return(double(tls_sni01: nil))

        expect {
          outcome = subject.run

          expect(outcome).to_not be_success
          expect(outcome.errors.message).to eq 'challenge' => "LE did not offer any tls-sni-01 challenge"
        }.not_to change{GridDomainAuthorization.count}
      end
    end
  end
end

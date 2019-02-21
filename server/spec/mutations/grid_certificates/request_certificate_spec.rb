describe GridCertificates::RequestCertificate do
  include FixturesHelpers

  let(:ca_pem) { fixture('certificates/test/ca.pem') }
  let(:cert_pem) { fixture('certificates/test/cert.pem') }
  let(:key_pem) { fixture('certificates/test/key.pem') }

  let(:subject) { described_class.new(grid: grid, secret_name: 'secret', domains: ['example.com']) }

  let(:grid) {
    Grid.create!(name: 'test-grid')
  }

  let(:acme_client) do
    double()
  end

  before :each do
    allow_any_instance_of(described_class).to receive(:acme_client).and_return(acme_client)
  end

  let(:authz) {
    GridDomainAuthorization.create!(grid: grid, domain: 'example.com',
      state: 'created',
      authorization_type: 'dns-01',
      expires_at: Time.now + 300,
      challenge: {},
      challenge_opts: {
        'record_name' => '_acme-challenge',
        'record_content' => '1234567890'
      },
    )
  }

  describe '#validate' do
    it 'validates domain authorization existence' do
      subject.validate
      expect(subject.has_errors?).to be_truthy
    end

    context 'dns-01' do

      it 'fails validation in domain challenge' do
        authz
        expect(subject).to receive(:validate_dns_record).and_return(false)
        subject.validate
        expect(subject.has_errors?).to be_truthy
      end

      it 'validates domain challenge' do
        authz
        expect(subject).to receive(:validate_dns_record).and_return(true)
        outcome = subject.validate
        expect(subject.has_errors?).to be_truthy
      end
    end

    context 'tls-sni-01' do
      # As of now there's no specific validations for tls-sni verification
    end

  end

  describe '#verify_domain' do
    let(:challenge) do
      double()
    end

    before :each do
      authz
      expect(acme_client).to receive(:challenge_from_hash).and_return(challenge)
    end

    it 'verifies domain succesfully' do
      expect(challenge).to receive(:request_verification).and_return(true)
      expect(challenge).to receive(:verify_status).and_return('valid', 'valid')

      expect{
        subject.verify_domain('example.com')
      }.to change{authz.reload.state}.from(:created).to(:validated)

      expect(authz.expires_at).to be nil
      expect(authz.status).to eq :validated
    end

    it 'fails if verify becomes invalid' do
      expect(challenge).to receive(:request_verification).and_return(true)
      expect(challenge).to receive(:verify_status).and_return('pending', 'invalid', 'invalid')
      expect(challenge).to receive(:error).and_return({'detail' => "Testing"})
      expect(subject).to receive(:add_error).with(:challenge, :invalid, "Testing")

      expect{
        subject.verify_domain('example.com')
      }.to change{authz.reload.state}.from(:created).to(:error)

      expect(authz.expires_at).to be nil
      expect(authz.status).to eq :error
    end

    it 'adds error if verification timeouts' do
      expect(challenge).to receive(:request_verification).and_return(true)
      expect(challenge).to receive(:verify_status).and_raise(Timeout::Error, "timeout after waiting ...")
      expect(subject).to receive(:add_error).with(:challenge_verify, :timeout, "Challenge verification timeout: timeout after waiting ...")

      expect{
        subject.verify_domain('example.com')
      }.to change{authz.reload.state}.from(:created).to(:requested)

      expect(authz.expires_at).to match Time
      expect(authz.status).to eq :requested
    end

    it 'adds error if acme server returns an error' do
      expect(challenge).to receive(:request_verification).and_return(false)
      expect(subject).to receive(:add_error)

      expect{
        subject.verify_domain('example.com')
      }.to_not change{authz.reload.state}.from(:created)

      expect(authz.expires_at).to match Time
      expect(authz.status).to eq :created
    end

    it 'adds error if acme client errors' do
      expect(challenge).to receive(:request_verification).and_raise(Acme::Client::Error)
      expect(subject).to receive(:add_error)

      expect{
        subject.verify_domain('example.com')
      }.to_not change{authz.reload.state}.from(:created)

      expect(authz.expires_at).to match Time
      expect(authz.status).to eq :created
    end
  end

  describe '#execute' do
    before :each do
      authz
      allow_any_instance_of(described_class).to receive(:verify_domain)
      allow_any_instance_of(described_class).to receive(:validate_dns_record).and_return(true)
      allow(acme_client).to receive(:new_certificate).and_return(acme_certificate)
    end

    let(:acme_certificate) do
      double({
        request: double(
          {
            private_key: double({to_pem: key_pem})
          }
        ),
        chain_to_pem: ca_pem,
        to_pem: cert_pem,
        x509: double(:not_after => Time.now + 90.days)
      })
    end

    it 'get fullchain cert by default' do
      expect {
        c = subject.execute
        expect(c.subject).to eq('example.com')
        expect(c.valid_until).not_to be_nil
        expect(c.alt_names).to be_empty
        expect(c.private_key).to eq(key_pem)
        expect(c.certificate).to eq(cert_pem)
        expect(c.chain).to eq(ca_pem)
        expect(c.full_chain).to eq(cert_pem + ca_pem)
        expect(c.bundle).to eq(cert_pem + ca_pem + key_pem)
      }.to change {grid.certificates.count}.by (1)
    end

    context 'with an existing certificate' do
      let!(:certificate) { Certificate.create!(grid: grid, subject: 'example.com',
        private_key: key_pem,
        certificate: cert_pem,
        valid_until: Time.now,
      ) }

      it 'updates cert' do
        subject = described_class.new(grid: grid, secret_name: 'secret', domains: ['example.com'])
        expect {
          subject.execute
        }.to not_change{grid.certificates.count}.and change{certificate.reload.updated_at}
      end
    end
  end


  describe '#validate_dns_record' do
    it 'returns false when wrong content in DNS record' do
      resolv = double
      allow(Resolv::DNS).to receive(:new).and_return(resolv)
      expect(resolv).to receive(:getresource).with("_acme-challenge.example.com", Resolv::DNS::Resource::IN::TXT).and_return(double(strings: ['dsdsdsdsds']))
      expect(subject.validate_dns_record('example.com', '1234567890')).to be_falsey

    end

    it 'returns false when DNS Failure' do
      resolv = double
      allow(Resolv::DNS).to receive(:new).and_return(resolv)
      expect(resolv).to receive(:getresource).with("_acme-challenge.example.com", Resolv::DNS::Resource::IN::TXT).and_raise(Resolv::ResolvError)
      expect(subject.validate_dns_record('example.com', '1234567890')).to be_falsey

    end

    it 'returns true when correct content in DNS record' do
      resolv = double
      allow(Resolv::DNS).to receive(:new).and_return(resolv)
      expect(resolv).to receive(:getresource).with("_acme-challenge.example.com", Resolv::DNS::Resource::IN::TXT).and_return(double(strings: ['1234567890']))
      expect(subject.validate_dns_record('example.com', '1234567890')).to be_truthy

    end
  end

  describe '#refresh_certificate_services' do
    let(:service) { GridService.create!(grid: grid, name: 'svc', image_name: 'redis:alpine') }

    let(:another_service) { GridService.create!(grid: grid, name: 'another-svc', image_name: 'redis:alpine') }

    let(:certificate) { Certificate.create!(grid: grid, subject: 'example.com',
      private_key: key_pem,
      certificate: cert_pem,
      valid_until: Time.now
    ) }

    it 'updates services if needed' do
      service.certificates << GridServiceCertificate.new(subject: certificate.subject)
      service.save

      expect {
        subject.refresh_certificate_services(certificate)
      }.to change {service.reload.updated_at}.and not_change{another_service.reload.updated_at}
    end
  end

end

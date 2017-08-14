
describe GridCertificates::GetCertificate do

  let(:subject) { described_class.new(grid: grid, secret_name: 'secret', domains: ['example.com']) }

  let(:grid) {
    Grid.create!(name: 'test-grid')
  }

  let(:authz) {
    challenge_opts = {
      'record_name' => '_acme-challenge',
      'record_content' => '1234567890'
    }
    authz = GridDomainAuthorization.create(grid: grid, domain: 'example.com', challenge: {}, challenge_opts: challenge_opts, authorization_type: 'dns-01')
    authz
  }

  describe '#validate' do
    it 'validates domain authorization existence' do
      subject.validate
      expect(subject.has_errors?).to be_truthy
    end

    it 'rejects invalid cert type' do
      outcome = described_class.run(grid: grid, secret_name: 'secret', domains: ['example.com'], cert_type: 'foo')
      expect(outcome).to_not be_success
      expect(outcome.errors.symbolic).to eq 'cert_type' => :in
    end
    it 'rejects invalid multi-line cert type ' do
      outcome = described_class.run(grid: grid, secret_name: 'secret', domains: ['example.com'], cert_type: "cert\nfoobar")
      expect(outcome).to_not be_success
      expect(outcome.errors.symbolic).to eq 'cert_type' => :in
    end

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

  describe '#execute' do
    let(:secret) do
      GridSecret.create!(name: 'secret', value: 'secret')
    end

    let! :acme do
      double(:acme)
    end

    let! :challenge do
      double(:challenge)
    end

    before :each do
      allow(subject).to receive(:acme_client).and_return(acme)
      allow(acme).to receive(:challenge_from_hash).and_return(challenge)
    end

    it 'get fullchain cert by default' do
      authz
      expect(acme).to receive(:new_certificate).and_return(
        double({
          request: double(
            {
              private_key: double({to_pem: 'private_key'})
            }
          ),
          fullchain_to_pem: 'fullchain'
        }))
      expect(challenge).to receive(:request_verification).and_return(true)
      expect(challenge).to receive(:verify_status).twice.and_return('valid')
      expect(subject).to receive(:upsert_secret).exactly(3).times.and_return(secret)
      expect(subject).to receive(:upsert_certificate)
      subject.execute
    end

    it 'get only cert' do
      subject = described_class.new(grid: grid, secret_name: 'secret', domains: ['example.com'], cert_type: 'cert')
      allow(subject).to receive(:acme_client).and_return(acme)
      authz
      expect(acme).to receive(:new_certificate).and_return(
        double({
          to_pem: 'pem_cert',
          request: double(
            {
              private_key: double({to_pem: 'private_key'})
            }
          )
        }))
      expect(challenge).to receive(:request_verification).and_return(true)
      expect(challenge).to receive(:verify_status).twice.and_return('valid')
      expect(subject).to receive(:upsert_secret).exactly(3).times.and_return(secret)
      expect(subject).to receive(:upsert_certificate)
      subject.execute
    end

    it 'get chain cert' do
      subject = described_class.new(grid: grid, secret_name: 'secret', domains: ['example.com'], cert_type: 'chain')
      allow(subject).to receive(:acme_client).and_return(acme)
      authz
      expect(acme).to receive(:new_certificate).and_return(
        double({
          request: double(
            {
              private_key: double({to_pem: 'private_key'})
            }
          ),
          chain_to_pem: 'chain'
        }))
      expect(challenge).to receive(:request_verification).and_return(true)
      expect(challenge).to receive(:verify_status).twice.and_return('valid')
      expect(subject).to receive(:upsert_secret).exactly(3).times.and_return(secret)
      expect(subject).to receive(:upsert_certificate)

      subject.execute
    end

    it 'adds error if verification timeouts' do
      authz
      expect(challenge).to receive(:request_verification).and_return(true)
      expect(challenge).to receive(:verify_status).and_raise(Timeout::Error)
      expect(subject).to receive(:add_error)

      subject.execute
    end

    it 'adds error if acme client errors' do
      authz

      expect(challenge).to receive(:request_verification).and_raise(Acme::Client::Error)
      expect(subject).to receive(:add_error)

      subject.execute
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

  describe '#upsert_secret' do
    it 'creates new secret' do
      expect(GridSecrets::Create).to receive(:run).and_return(double({success?: true, result: double}))
      subject.upsert_secret('foo', 'cert_content')
    end

    it 'updates secret' do
      secret = GridSecret.create!(name: 'secret', value: 'secret')
      grid.grid_secrets << secret
      expect(GridSecrets::Update).to receive(:run).and_return(double({success?: true, result: double}))

      subject.upsert_secret('secret', 'cert_content')

    end

    it 'adds error if secret upsert fails' do
      expect(GridSecrets::Create).to receive(:run).and_return(double({success?: false, errors: double({message:'error'})}))
      expect(subject).to receive(:add_error)
      subject.upsert_secret('foo', 'cert_content')
    end
  end

  describe '#upsert_certificate' do
    it 'updates existing certificate model' do
      secret = GridSecret.create!(name: 'secret', value: 'secret')
      cert = Certificate.create!(
        grid: grid,
        domain: 'bar.com',
        valid_until: DateTime.now,
        alt_names: ['foo.bar.com'],
        cert_type: 'fullchain',
        private_key: secret,
        certificate: secret,
        certificate_bundle: secret
      )
      expect {
        subject.upsert_certificate(
          grid,
          ['bar.com', 'foo.bar.com'],
          double(:certificate, {:x509 => double({:subject => double({:to_s => '/CN=bar.com'}), :not_after => DateTime.now + 90})}),
          secret,
          secret,
          secret,
          'fullchain'
        )
      }.to change{cert.reload.valid_until}
    end

    it 'creates new certificate model' do
      secret = GridSecret.create!(name: 'secret', value: 'secret')
      expect {
        subject.upsert_certificate(
          grid,
          ['bar.com', 'foo.bar.com'],
          double(:certificate, {:x509 => double({:subject => double({:to_s => '/CN=bar.com'}), :not_after => DateTime.now + 90})}),
          secret,
          secret,
          secret,
          'fullchain'
        )
      }.to change{Certificate.count}.by (1)
      cert = grid.certificates.first
      expect(cert.domain).to eq('bar.com')
      expect(cert.alt_names).to eq(['foo.bar.com'])
    end
  end

end


describe GridCertificates::GetCertificate do

  let(:subject) { described_class.new(grid: grid, secret_name: 'secret', domains: ['example.com']) }

  let(:grid) {
    Grid.create!(name: 'test-grid')
  }

  let(:authz) {
    opts = {
      'record_name' => '_acme-challenge',
      'record_content' => '1234567890'
    }
    GridDomainAuthorization.create!(grid: grid, domain: 'example.com', authorization_type: 'dns-01', challenge: nil, challenge_opts: opts)
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

    end

  end

  describe '#execute' do
    it 'get fullchain cert by default' do
      authz
      acme = double
      allow(subject).to receive(:acme_client).and_return(acme)
      challenge = double
      expect(acme).to receive(:challenge_from_hash).and_return(challenge)
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
      expect(challenge).to receive(:verify_status).and_return('valid', 'valid')
      expect(subject).to receive(:upsert_secret).exactly(3).times.and_return(double({success?: true}))

      subject.execute
    end

    it 'get only cert' do
      subject = described_class.new(grid: grid, secret_name: 'secret', domains: ['example.com'], cert_type: 'cert')
      authz
      acme = double
      allow(subject).to receive(:acme_client).and_return(acme)
      challenge = double
      expect(acme).to receive(:challenge_from_hash).and_return(challenge)
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
      expect(challenge).to receive(:verify_status).and_return('valid', 'valid')
      expect(subject).to receive(:upsert_secret).exactly(3).times.and_return(double({success?: true}))

      subject.execute
    end

    it 'get chain cert' do
      subject = described_class.new(grid: grid, secret_name: 'secret', domains: ['example.com'], cert_type: 'chain')
      authz
      acme = double
      allow(subject).to receive(:acme_client).and_return(acme)
      challenge = double
      expect(acme).to receive(:challenge_from_hash).and_return(challenge)
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
      expect(challenge).to receive(:verify_status).and_return('valid', 'valid')
      expect(subject).to receive(:upsert_secret).exactly(3).times.and_return(double({success?: true}))

      subject.execute
    end

    it 'adds error if verification timeouts' do
      authz
      acme = double
      allow(subject).to receive(:acme_client).and_return(acme)
      challenge = double
      expect(acme).to receive(:challenge_from_hash).and_return(challenge)
      expect(challenge).to receive(:request_verification).and_return(true)
      expect(challenge).to receive(:verify_status).and_raise(Timeout::Error)
      expect(subject).to receive(:add_error)

      subject.execute
    end

    it 'adds error if acme client errors' do
      authz
      acme = double
      allow(subject).to receive(:acme_client).and_return(acme)
      challenge = double
      expect(acme).to receive(:challenge_from_hash).and_return(challenge)
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

end

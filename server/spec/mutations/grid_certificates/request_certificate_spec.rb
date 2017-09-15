
describe GridCertificates::RequestCertificate do

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
    opts = {
      'record_name' => '_acme-challenge',
      'record_content' => '1234567890'
    }
    GridDomainAuthorization.create!(grid: grid, domain: 'example.com', authorization_type: 'dns-01', challenge: {}, challenge_opts: opts)
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

      subject.verify_domain('example.com')
    end

    it 'adds error if verification timeouts' do
      expect(challenge).to receive(:request_verification).and_return(true)
      expect(challenge).to receive(:verify_status).and_raise(Timeout::Error)
      expect(subject).to receive(:add_error)

      subject.verify_domain('example.com')
    end

    it 'adds error if acme client errors' do
      expect(challenge).to receive(:request_verification).and_raise(Acme::Client::Error)
      expect(subject).to receive(:add_error)

      subject.verify_domain('example.com')
    end


  end

  describe '#execute' do
    before :each do
      authz
      allow_any_instance_of(described_class).to receive(:verify_domain)
      allow_any_instance_of(described_class).to receive(:validate_dns_record).and_return(true)
      allow(acme_client).to receive(:new_certificate).and_return(certificate)
    end

    let(:certificate) do
      double({
        request: double(
          {
            private_key: double({to_pem: 'private_key'})
          }
        ),
        chain_to_pem: 'chain',
        fullchain_to_pem: 'fullchain',
        to_pem: 'certificate_only',
        x509: double(:not_after => Time.now + 90.days)
      })
    end

    it 'get fullchain cert by default' do
      expect {
        c = subject.execute
        expect(c.subject).to eq('example.com')
        expect(c.valid_until).not_to be_nil
        expect(c.alt_names).to be_empty
        expect(c.private_key).to eq('private_key')
        expect(c.certificate).to eq('certificate_only')
        expect(c.chain).to eq('chain')
        expect(c.full_chain).to eq('certificate_onlychain')
        expect(c.bundle).to eq('certificate_onlychainprivate_key')
      }.to change {grid.certificates.count}.by (1)
    end

    it 'updates cert' do
      subject = described_class.new(grid: grid, secret_name: 'secret', domains: ['example.com'])
      certificate = Certificate.create!(grid: grid, subject: 'example.com', valid_until: Time.now)
      expect {
        subject.execute
      }.to not_change{grid.certificates.count}.and change{certificate.reload.updated_at}
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

  describe '#refresh_grid_services' do
    let(:service) { GridService.create!(grid: grid, name: 'svc', image_name: 'redis:alpine') }

    let(:another_service) { GridService.create!(grid: grid, name: 'another-svc', image_name: 'redis:alpine') }

    let(:certificate) { Certificate.create!(grid: grid, subject: 'example.com', valid_until: Time.now) }

    it 'updates services if needed' do
      service.certificates << GridServiceCertificate.new(subject: certificate.subject)
      service.save

      expect {
        subject.refresh_grid_services(certificate)
      }.to change {service.reload.updated_at}.and not_change{another_service.reload.updated_at}
    end
  end

end

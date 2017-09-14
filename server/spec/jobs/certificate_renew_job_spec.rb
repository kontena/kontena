
describe CertificateRenewJob, celluloid: true do

  let(:subject) { described_class.new(false) }

  let(:grid) { Grid.create!(name: 'test-grid') }

  let(:service) { GridService.create!(grid: grid, name: 'lb', image_name: 'lb')}

  let(:certificate) {
    Certificate.create!(grid: grid,
      subject: 'kontena.io',
      valid_until: Time.now + 90.days,
      private_key: 'private_key',
      certificate: 'certificate',
      chain: 'chain')
  }

  describe '#should_renew?' do
    it 'returns false if no need to renew' do
      expect(subject.should_renew?(certificate)).to be_falsey
    end

    it 'returns true when need to renew' do
      certificate.valid_until = Time.now + 6.days
      expect(subject.should_renew?(certificate)).to be_truthy
    end
  end

  describe '#can_renew?' do
    it 'returns false if some domain not tls-sni authorized' do
      GridDomainAuthorization.create!(grid: grid, domain: 'kontena.io', authorization_type: 'dns-01')
      expect(subject.can_renew?(certificate)).to be_falsey
    end

    it 'returns true when all domains tls-sni authorized' do
      GridDomainAuthorization.create!(grid: grid, domain: 'kontena.io', authorization_type: 'tls-sni-01')
      expect(subject.can_renew?(certificate)).to be_truthy
    end
  end

  describe '#authorize_domains' do
    it 'authorises domain succesfully' do
      domain_auth = GridDomainAuthorization.create!(grid: grid, domain: 'kontena.io', authorization_type: 'tls-sni-01', grid_service: service)
      expect(GridDomainAuthorizations::Authorize).to receive(:run).and_return(double(:success? => true, :result => domain_auth))
      expect(subject.wrapped_object).to receive(:wait_until!)
      subject.authorize_domains(certificate)
    end

    it 'raises if domain auth fails' do
      domain_auth = GridDomainAuthorization.create!(grid: grid, domain: 'kontena.io', authorization_type: 'tls-sni-01', grid_service: service)
      expect(GridDomainAuthorizations::Authorize).to receive(:run).and_return(double(:success? => false, :errors => double(:message => 'boom')))
      expect {
        subject.authorize_domains(certificate)
      }.to raise_error "Domain authorization failed: boom"
    end
  end

end

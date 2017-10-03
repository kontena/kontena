
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

  describe '#renew_certificates' do
    it 'renews only those that are going old within 7 days' do
      cert2 = Certificate.create!(grid: grid,
          subject: 'www.kontena.io',
          valid_until: Time.now + 5.days,
          private_key: 'private_key',
          certificate: 'certificate',
          chain: 'chain')
      expect(subject.wrapped_object).to receive(:renew_certificate).with(cert2)
      subject.renew_certificates
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

    it 'raises if tls-sni deployment fails' do
      domain_auth = GridDomainAuthorization.create!(grid: grid, domain: 'kontena.io', authorization_type: 'tls-sni-01', grid_service: service)
      expect(domain_auth).to receive(:status).twice.and_return(:deploy_error) #once in the wait loop and once after it
      expect(GridDomainAuthorizations::Authorize).to receive(:run).and_return(double(:success? => true, :result => domain_auth))
      expect {
        subject.authorize_domains(certificate)
      }.to raise_error "Deployment of tls-sni secret failed"
    end
  end

end

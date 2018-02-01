
describe CertificateRenewJob, celluloid: true do

  let(:subject) { described_class.new(false) }

  let(:grid) { Grid.create!(name: 'test-grid') }

  let(:linked_service) { GridService.create!(grid: grid, name: 'lb', image_name: 'lb')}

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

  context 'without any domain authz' do
    describe '#renew_certificate' do
      it 'does not renew the certificate' do
        expect(subject.wrapped_object).to_not receive(:authorize_domains)
        expect(subject.wrapped_object).to_not receive(:request_new_cert)

        subject.renew_certificate(certificate)
      end
    end
  end

  context 'with a non-renewable domain authz' do
    let(:domain_auth) { GridDomainAuthorization.create!(grid: grid, domain: 'kontena.io', authorization_type: 'dns-01') }

    describe '#renew_certificate' do
      it 'does not renew the certificate' do
        expect(subject.wrapped_object).to_not receive(:authorize_domains)
        expect(subject.wrapped_object).to_not receive(:request_new_cert)

        subject.renew_certificate(certificate)
      end
    end
  end

  context 'with an auto-renewable tls-sni-01 domain authz' do
    let!(:domain_auth) { GridDomainAuthorization.create!(grid: grid, domain: 'kontena.io',
      authorization_type: 'tls-sni-01',
      grid_service: linked_service,
    ) }

    describe '#renew_certificate' do
      before do
        expect(certificate).to be_auto_renewable
      end

      it 're-authorizes and renews the cert' do
        expect(subject.wrapped_object).to receive(:authorize_domains).with(certificate)
        expect(subject.wrapped_object).to receive(:request_new_cert).with(certificate)

        subject.renew_certificate(certificate)
      end

    end

    describe '#authorize_domains' do
      it 'authorises domain succesfully' do
        expect(GridDomainAuthorizations::Authorize).to receive(:run).with(
          grid: grid,
          domain: 'kontena.io',
          authorization_type: 'tls-sni-01',
          linked_service: 'null/lb',
        ).and_return(double(:success? => true, :result => domain_auth))
        allow(subject.wrapped_object).to receive(:wait_until!)

        subject.authorize_domains(certificate)
      end

      it 'raises if domain auth fails' do
        expect(GridDomainAuthorizations::Authorize).to receive(:run).and_return(double(:success? => false, :errors => double(:message => 'boom')))
        expect {
          subject.authorize_domains(certificate)
        }.to raise_error "Domain authorization failed: boom"
      end

      it 'raises if tls-sni deployment fails' do
        expect(domain_auth).to receive(:status).twice.and_return(:deploy_error) #once in the wait loop and once after it
        expect(GridDomainAuthorizations::Authorize).to receive(:run).and_return(double(:success? => true, :result => domain_auth))
        expect {
          subject.authorize_domains(certificate)
        }.to raise_error "Deployment of tls-sni secret failed"
      end
    end

    context 'with the linked service having been removed' do
      before do
        linked_service.destroy
        certificate.reload
      end

      describe '#renew_certificate' do
        it 'does not renew the cert' do
          expect(subject.wrapped_object).to_not receive(:request_new_cert)
          expect(subject.wrapped_object).to_not receive(:error)

          subject.renew_certificate(certificate)
        end
      end
    end
  end

  context 'with an auto-renewable http-01 domain authz' do
    let!(:domain_auth) { GridDomainAuthorization.create!(grid: grid, domain: 'kontena.io',
      authorization_type: 'http-01',
      grid_service: linked_service,
    ) }

    describe '#renew_certificate' do
      before do
        expect(certificate).to be_auto_renewable
      end

      it 're-authorizes and renews the cert' do
        expect(subject.wrapped_object).to receive(:authorize_domains).with(certificate)
        expect(subject.wrapped_object).to receive(:request_new_cert).with(certificate)

        subject.renew_certificate(certificate)
      end

    end

    describe '#authorize_domains' do
      it 'authorises domain succesfully' do
        expect(GridDomainAuthorizations::Authorize).to receive(:run).with(
          grid: grid,
          domain: 'kontena.io',
          authorization_type: 'http-01',
          linked_service: 'null/lb',
        ).and_return(double(:success? => true, :result => domain_auth))

        subject.authorize_domains(certificate)
      end
    end
  end
end

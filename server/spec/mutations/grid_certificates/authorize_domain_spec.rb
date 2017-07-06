
describe GridCertificates::AuthorizeDomain do

  let(:grid) {
    Grid.create!(name: 'test-grid')
  }

  context 'dns01 validation' do

    let(:subject) { described_class.new(grid: grid, domain: 'example.com') }

    let(:authz) {
      challenge_opts = {
        'record_name' => '_acme-challenge',
        'record_content' => '1234567890'
      }
      authz = GridDomainAuthorization.create(grid: grid, domain: 'example.com', challenge: {}, challenge_opts: challenge_opts)
      authz
    }

    describe '#execute' do
      it 'sends verification request and creates new authorization' do
        acme = double
        allow(subject).to receive(:acme_client).and_return(acme)
        auth = double({dns01: double(
          {
            record_name: '_acme_challenge',
            record_type: 'TXT',
            record_content: '123456789',
            to_h: {}
          })})
        expect(acme).to receive(:authorize).with(domain: 'example.com').and_return(auth)

        expect {
          subject.execute
        }.to change{GridDomainAuthorization.count}.by(1)

      end

      it 'fails gracefully if no LE registration' do
        acme = double
        allow(subject).to receive(:acme_client).and_return(acme)
        expect(acme).to receive(:authorize).and_raise(Acme::Client::Error::Unauthorized)

        expect {
          outcome = subject.run
          expect(outcome.success?).to be_falsey
        }.not_to change{GridDomainAuthorization.count}

      end

      it 'sends verification request and updates authorization' do
        acme = double
        allow(subject).to receive(:acme_client).and_return(acme)
        auth = double({dns01: double(
          {
            record_name: '_acme_challenge',
            record_type: 'TXT',
            record_content: '123456789',
            to_h: {}
          })})
        expect(acme).to receive(:authorize).with(domain: 'example.com').and_return(auth)

        expect {
          subject.execute
        }.to change{authz.reload.updated_at}

      end
    end
  end

  context 'tls-sni-01 validation' do
    it 'sends verification request and creates new authorization' do
      subject = described_class.new(grid: grid, domain: 'example.com', authorization_type: 'tls-sni-01')
      acme = double
      allow(subject).to receive(:acme_client).and_return(acme)
      auth = double({
        tls_sni01: double(
          {
            certificate: double({:to_pem => "foo"}),
            private_key: double({:to_pem => "bar"}),
            to_h: {}
          })
      })
      expect(acme).to receive(:authorize).with(domain: 'example.com').and_return(auth)

      expect {
        subject.execute
      }.to change{GridDomainAuthorization.count}.by(1)
      expect(GridSecret.find_by(name: 'LE_TLS_SNI_example_com').value).to eq('foobar')

    end

    it 'sends verification request and updates needed service' do
      lb_service = grid.grid_services.create!(name: 'lb', image_name: 'kontena/lb')
      subject = described_class.new(grid: grid, domain: 'example.com', authorization_type: 'tls-sni-01', lb_link: 'null/lb')
      subject.validate
      acme = double
      allow(subject).to receive(:acme_client).and_return(acme)
      auth = double({
        tls_sni01: double(
          {
            certificate: double({:to_pem => "foo"}),
            private_key: double({:to_pem => "bar"}),
            to_h: {}
          })
      })
      expect(acme).to receive(:authorize).with(domain: 'example.com').and_return(auth)

      expect {
        subject.execute
      }.to change{GridDomainAuthorization.count}.by(1)
      expect(GridSecret.find_by(name: 'LE_TLS_SNI_example_com').value).to eq('foobar')
      expect(lb_service.reload.secrets[0]['secret']).to eq('LE_TLS_SNI_example_com')

    end
  end


end

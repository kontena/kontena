
describe GridDomainAuthorizations::Authorize do

  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid
  }

  let(:acme) {
    instance_double(Acme::Client)
  }

  before :each do
    allow(subject).to receive(:acme_client).and_return(acme)
  end

  describe '#validate' do

    before :each do

      GridSecrets::Create.run(grid: grid, name: 'LE_PRIVATE_KEY', value: 'LE_PRIVATE_KEY')

    end

    it 'validate LE registration existence' do
      GridSecret.find_by(name: 'LE_PRIVATE_KEY').destroy
      outcome = described_class.validate(grid: grid, domain: 'example.com', authorization_type: 'dns-01')
      expect(outcome).not_to be_success
      expect(outcome.errors.message['le_registration']).to eq('Let\'s Encrypt registration missing')
    end

    it 'validates service existence when tls-sni used' do
      mutation = described_class.new(grid: grid, domain: 'example.com', linked_service: 'non/existing', authorization_type: 'tls-sni-01')
      expect(mutation.has_errors?).to be_truthy
    end

    it 'validates service existence when tls-sni used' do
      GridService.create(grid: grid, name: 'web', image_name: 'web:latest')
      mutation = described_class.new(grid: grid, domain: 'example.com', linked_service: 'null/web', authorization_type: 'tls-sni-01')
      expect(mutation.has_errors?).to be_falsey
    end

  end

  let(:subject) { described_class.new(grid: grid, domain: 'example.com') }

  describe '#execute' do
    context 'dns-01' do

      let(:authz) {
        challenge_opts = {
          'record_name' => '_acme-challenge',
          'record_content' => '1234567890'
        }
        GridDomainAuthorization.create(grid: grid, domain: 'example.com', challenge: {}, challenge_opts: challenge_opts)
      }

      it 'sends verification request and creates new authorization' do
        auth = double({dns01: double(
          {
            record_name: '_acme_challenge',
            record_type: 'TXT',
            record_content: '123456789',
            to_h: {}
          })})
        expect(acme).to receive(:authorize).with(domain: 'example.com').and_return(auth)


        subject.execute
        # Domain authorization is always inserted "fresh"
        expect(GridDomainAuthorization.find_by(domain: 'example.com').id).not_to eq(authz.id)

      end

      it 'fails if LE gives no challenge' do
        auth = double(dns01: nil)
        expect(acme).to receive(:authorize).with(domain: 'example.com').and_return(auth)

        expect {
          subject.execute
          expect(subject.has_errors?).to be_truthy
        }.not_to change{GridDomainAuthorization.count}

      end
    end

  end

  context 'tls-sni-01' do
    let(:web) {
      GridService.create(grid: grid, name: 'web', image_name: 'web:latest')
    }

    let(:subject) { described_class.new(grid: grid, domain: 'example.com', linked_service: 'null/web', authorization_type: 'tls-sni-01') }


    it 'sends verification request and creates new authorization' do
      web
      auth = double(tls_sni01: double(
        certificate: double(to_pem: 'CERTIFICATE'),
        private_key: double(to_pem: 'PRIVATE_KEY'),
        to_h: {}
      ))
      expect(acme).to receive(:authorize).with(domain: 'example.com').and_return(auth)

      subject.validate
      subject.execute

      auth = grid.grid_domain_authorizations.find_by(domain: 'example.com')
      expect(auth.grid_service_deploy).not_to be_nil
      expect(auth.tls_sni_certificate).to eq('CERTIFICATEPRIVATE_KEY')
    end

    it 'fails if LE gives no challenge' do
        auth = double(tls_sni01: nil)
        expect(acme).to receive(:authorize).with(domain: 'example.com').and_return(auth)

        expect {
          subject.execute
          expect(subject.has_errors?).to be_truthy
        }.not_to change{GridDomainAuthorization.count}

      end
  end

end

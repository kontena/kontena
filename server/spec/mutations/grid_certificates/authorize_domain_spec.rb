require_relative '../../spec_helper'

describe GridCertificates::AuthorizeDomain do

  let(:subject) { described_class.new(grid: grid, domain: 'example.com') }
  
  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid
  }

  let(:authz) {
    challenge_opts = {
      'record_name' => '_acme-challenge',
      'record_content' => '1234567890'
    }
    authz = GridDomainAuthorization.create(grid: grid, domain: 'example.com', challenge: {}, challenge_opts: challenge_opts)
    authz
  }
  
  describe '#validate' do

  end

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

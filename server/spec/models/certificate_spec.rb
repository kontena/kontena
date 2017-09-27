describe Certificate do
  it { should be_timestamped_document }

  it { should belong_to(:grid) }


  describe '#auto_renewable?' do

    let(:grid) { Grid.create!(name: 'test-grid') }

    let(:certificate) {
      Certificate.create!(grid: grid,
        subject: 'kontena.io',
        valid_until: Time.now + 90.days,
        private_key: 'private_key',
        certificate: 'certificate',
        alt_names: ['www.kontena.io'],
        chain: 'chain')
    }

    it 'returns false if some domain not tls-sni authorized' do
      GridDomainAuthorization.create!(grid: grid, domain: 'kontena.io', authorization_type: 'tls-sni-01')
      GridDomainAuthorization.create!(grid: grid, domain: 'www.kontena.io', authorization_type: 'dns-01')
      expect(certificate.auto_renewable?).to be_falsey
    end

    it 'returns true when all domains tls-sni authorized' do
      GridDomainAuthorization.create!(grid: grid, domain: 'kontena.io', authorization_type: 'tls-sni-01')
      GridDomainAuthorization.create!(grid: grid, domain: 'www.kontena.io', authorization_type: 'tls-sni-01')
      expect(certificate.auto_renewable?).to be_truthy
    end
  end

end

describe Certificate do
  it { should be_timestamped_document }
  it { should belong_to(:grid) }

  let(:grid) { Grid.create!(name: 'test-grid') }

  let(:certificate) {
    Certificate.create!(grid: grid,
      subject: 'kontena.io',
      valid_until: Time.now + 90.days,
      private_key: 'private_key',
      certificate: 'certificate',
      alt_names: ['www.kontena.io'],
      chain: 'chain',
    )
  }

  it 'gets cleaned up if the grid is deleted' do
    expect{
      grid.destroy!
    }.to change {Certificate.find_by(subject: 'kontena.io')}.from(certificate).to(nil)
  end

  describe '#to_path' do
    context 'for a deleted grid' do
      before do
        grid.destroy!
        certificate.reload
      end

      it 'retuns a broken path instead of crashing' do
        path = nil

        expect{path = certificate.to_path}.to_not raise_error
        expect(path).to eq '/kontena.io'
      end
    end
  end

  describe '#auto_renewable?' do
    context 'with missing subject domain authorizations' do
      let!(:authz1) { GridDomainAuthorization.create!(grid: grid, domain: 'www.kontena.io', authorization_type: 'tls-sni-01') }

      it 'is not auto-renewable' do
        expect(certificate).to_not be_auto_renewable
      end
    end

    context 'with missing alt domain authorizations' do
      let!(:authz1) { GridDomainAuthorization.create!(grid: grid, domain: 'kontena.io', authorization_type: 'tls-sni-01') }

      it 'is not auto-renewable' do
        expect(certificate).to_not be_auto_renewable
      end
    end

    context 'with non-tls-sni domain authorizations' do
      let!(:authz1) { GridDomainAuthorization.create!(grid: grid, domain: 'kontena.io', authorization_type: 'tls-sni-01') }
      let!(:authz2) { GridDomainAuthorization.create!(grid: grid, domain: 'www.kontena.io', authorization_type: 'dns-01') }

      it 'is not auto-renewable' do
        expect(certificate).to_not be_auto_renewable
      end
    end

    context 'with tls-sni domain authorizations missing any linked service' do
      let!(:authz1) { GridDomainAuthorization.create!(grid: grid, domain: 'kontena.io', authorization_type: 'tls-sni-01') }
      let!(:authz2) { GridDomainAuthorization.create!(grid: grid, domain: 'www.kontena.io', authorization_type: 'tls-sni-01') }

      it 'is not auto-renewable' do
        expect(certificate).to_not be_auto_renewable
      end
    end

    context 'with tls-sni domain authorizations having a linked service' do
      let(:linked_service) { GridService.create!(grid: grid, name: 'lb', image_name: 'lb')}

      let!(:authz1) { GridDomainAuthorization.create!(grid: grid, domain: 'kontena.io', authorization_type: 'tls-sni-01', grid_service: linked_service) }
      let!(:authz2) { GridDomainAuthorization.create!(grid: grid, domain: 'www.kontena.io', authorization_type: 'tls-sni-01', grid_service: linked_service) }

      it 'is auto-renewable' do
        expect(certificate).to be_auto_renewable
      end
    end

    context 'with http domain authorizations having a linked service' do
      let(:linked_service) { GridService.create!(grid: grid, name: 'lb', image_name: 'lb')}

      let!(:authz1) { GridDomainAuthorization.create!(grid: grid, domain: 'kontena.io', authorization_type: 'http-01', grid_service: linked_service) }
      let!(:authz2) { GridDomainAuthorization.create!(grid: grid, domain: 'www.kontena.io', authorization_type: 'http-01', grid_service: linked_service) }

      it 'is auto-renewable' do
        expect(certificate).to be_auto_renewable
      end
    end
  end
end

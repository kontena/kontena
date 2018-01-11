describe GridDomainAuthorization do
  it { should have_fields(:domain).of_type(String)}
  it { should have_fields(:challenge, :challenge_opts).of_type(Hash) }

  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:lb_service) { GridService.create!(grid: grid, name: 'lb',
      image_name: 'kontena/lb:latest'
  ) }

  describe 'when created' do
    subject {
      described_class.create!(grid: grid,
        state: :created,
        domain: 'example.com',
        authorization_type: 'tls-sni-01',
        expires_at: Time.now + 300,
        grid_service: lb_service,
        tls_sni_certificate: 'TLS_AUTH',
      )
    }

    it 'is pending' do
      expect(subject).to be_pending
    end

    it 'is not expired' do
      expect(subject).to_not be_expired
    end

    it 'is deployable' do
      expect(subject).to be_deployable
    end
  end

  describe 'when requested' do
    let(:expires_at) { Time.now + 300 }

    subject {
      described_class.create!(grid: grid,
        state: :requested,
        domain: 'example.com',
        authorization_type: 'tls-sni-01',
        expires_at: expires_at,
        grid_service: lb_service,
        tls_sni_certificate: 'TLS_AUTH',
      )
    }

    it 'is pending' do
      expect(subject).to be_pending
    end

    it 'is not expired' do
      expect(subject).to_not be_expired
    end

    it 'is deployable' do
      expect(subject).to be_deployable
    end

    context 'when expired' do
      let(:expires_at) { Time.now - 300 }

      it 'is pending' do
        expect(subject).to be_pending
      end

      it 'is expired' do
        expect(subject).to be_expired
      end

      it 'is not deployable' do
        expect(subject).to_not be_deployable
      end
    end
  end

  describe 'when failed' do
    subject {
      described_class.create!(grid: grid,
        state: :error,
        domain: 'example.com',
        authorization_type: 'tls-sni-01',
        expires_at: nil,
        grid_service: lb_service,
        tls_sni_certificate: 'TLS_AUTH',
      )
    }

    it 'is not pending' do
      expect(subject).to_not be_pending
    end

    it 'is not expired' do
      expect(subject).to_not be_expired
    end

    it 'is not deployable' do
      expect(subject).to_not be_deployable
    end
  end

  describe 'when validated' do
    subject {
      described_class.create!(grid: grid,
        state: :validated,
        domain: 'example.com',
        authorization_type: 'tls-sni-01',
        expires_at: nil,
        grid_service: lb_service,
        tls_sni_certificate: 'TLS_AUTH',
      )
    }

    it 'is not pending' do
      expect(subject).to_not be_pending
    end

    it 'is not expired' do
      expect(subject).to_not be_expired
    end

    it 'is not deployable' do
      expect(subject).to_not be_deployable
    end
  end
end

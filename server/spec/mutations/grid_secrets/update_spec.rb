
describe GridSecrets::Update do

  let(:subject) { described_class.new(grid_secret: grid_secret, value: 'v3rys3cr3t')}
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << user
    grid
  }
  let(:grid_secret) do
    secret = GridSecret.create!(name: 'secret', value: 'secret')
    grid.grid_secrets << secret
    secret
  end
  let(:web) {
    service = GridService.create(grid: grid, name: 'web', image_name: 'web:latest')
    service.secrets << GridServiceSecret.create(grid_service: service, secret: 'secret', name: 'service_secret', type: 'env')
    service
  }

  describe '#run' do
    it 'updates grid secret' do
      expect {
        subject.run
      }.to change{ grid_secret.reload.value }.to('v3rys3cr3t')
    end

    it 'does not update secret if value does not change' do
      mutation = described_class.new(grid_secret: grid_secret, value: grid_secret.value)
      expect {
        mutation.run
      }.not_to change { grid_secret.reload.updated_at }
    end

    it 'updated related grid services timestamp' do
      web # create
      expect {
        subject.run
      }.to change{ web.reload.updated_at }
    end

    it 'does not update related grid_services if value does not change' do
      web # create
      mutation = described_class.new(grid_secret: grid_secret, value: grid_secret.value)
      expect {
        mutation.run
      }.not_to change { web.reload.updated_at }
    end
  end
end

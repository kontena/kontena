
describe GridSecrets::Create do

  let(:subject) { described_class.new(grid: grid, name: 'secret', value: 'v3rys3cr3t') }
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << user
    grid
  }
  let(:web) {
    service = GridService.create(grid: grid, name: 'web', image_name: 'web:latest')
    service.secrets << GridServiceSecret.create(grid_service: service, secret: 'secret', name: 'service_secret', type: 'env')
    service
  }
  let(:db) {
    service = GridService.create(grid: grid, name: 'db', image_name: 'redis:2.8')
    service.secrets << GridServiceSecret.create(grid_service: service, secret: 'db_secret', name: 'service_secret', type: 'env')
    service
  }

  describe '#run' do
    it 'creates a new grid secret' do
      expect {
        subject.run
      }.to change{ GridSecret.count }.by(1)
    end

    it 'updates related grid services' do
      web # create
      db # create
      hour_ago = Time.now.utc - 1.hour
      web.set(updated_at: hour_ago)
      db.set(updated_at: hour_ago)
      subject.run
      expect(web.reload.updated_at.to_s).not_to eq(hour_ago.to_s)
      expect(db.reload.updated_at.to_s).to eq(hour_ago.to_s)
    end
  end
end

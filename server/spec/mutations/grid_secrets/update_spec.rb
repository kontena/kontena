require_relative '../../spec_helper'

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
  let(:db) {
    service = GridService.create(grid: grid, name: 'db', image_name: 'redis:2.8')
    service.secrets << GridServiceSecret.create(grid_service: service, secret: 'db_secret', name: 'service_secret', type: 'env')
    service
  }
  let(:worker) { spy(:worker) }

  describe '#run' do
    before(:each) do
      allow(subject).to receive(:worker).with(:grid_service_scheduler).and_return(worker)
    end

    it 'updates grid secret' do
      expect {
        subject.run
      }.to change{ grid_secret.reload.value }.to('v3rys3cr3t')
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

    it 'schedules deploy for related grid services' do
      web # create
      db # create
      expect(subject).to receive(:worker).with(:grid_service_scheduler).once.and_return(worker)
      expect(worker).to receive(:perform).once.with(web.id)
      expect(worker).not_to receive(:perform).with(db.id)
      subject.run
    end
  end
end

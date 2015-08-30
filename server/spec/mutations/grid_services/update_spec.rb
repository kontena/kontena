require_relative '../../spec_helper'

describe GridServices::Update do
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << user
    grid
  }
  let(:redis_service) { GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8')}

  describe '#run' do
    it 'updates env variables' do
      redis_service.env = ['FOO=BAR', 'BAR=baz']
      redis_service.save
      expect {
        described_class.new(
            current_user: user,
            grid_service: redis_service,
            env: ['FOO=bar']
        ).run
      }.to change{ redis_service.reload.env }.to(['FOO=bar', 'BAR=baz'])
    end

    it 'updates affinity variables' do
      redis_service.affinity = ['az==a1', 'disk==ssd']
      redis_service.save
      expect {
        described_class.new(
            current_user: user,
            grid_service: redis_service,
            affinity: ['az==b1']
        ).run
      }.to change{ redis_service.reload.affinity }.to(['az==b1'])
    end
  end
end

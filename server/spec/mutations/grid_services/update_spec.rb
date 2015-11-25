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
      }.to change{ redis_service.reload.env }.to(['FOO=bar'])
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

  describe '#build_grid_service_hooks' do
    let(:subject) do
      described_class.new(
        current_user: user,
        grid_service: redis_service,
        hooks: {
          post_start: [
            {
              name: 'foo',
              cmd: 'sleep 10',
              instances: ["1", "2"],
              oneshot: false
            }
          ]
        }
      )
    end

    it 'builds hook' do
      hooks = subject.build_grid_service_hooks
      expect(hooks.size).to eq(1)
      expect(hooks[0].cmd).to eq('sleep 10')
    end

    it 'updates existing hook' do
      org_hook = GridServiceHook.new(
        name: 'foo',
        type: 'post_start',
        cmd: 'sleep 1',
        instances: ['*'],
        oneshot: false
      )
      redis_service.hooks << org_hook
      redis_service.save
      hooks = subject.build_grid_service_hooks(redis_service.hooks.to_a)
      expect(hooks.size).to eq(1)
      expect(hooks[0].id).to eq(org_hook.id)
      expect(hooks[0].cmd).to eq('sleep 10')
    end
  end
end

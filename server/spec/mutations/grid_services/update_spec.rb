require_relative '../../spec_helper'

describe GridServices::Update do
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:redis_service) { GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8')}

  describe '#run' do
    it 'updates env variables' do
      redis_service.env = ['FOO=BAR', 'BAR=baz']
      redis_service.save
      expect {
        described_class.new(
            grid_service: redis_service,
            env: ['FOO=bar']
        ).run
      }.to change{ redis_service.reload.env }.to(['FOO=bar'])
    end

    it 'updates revision' do
      redis_service.env = ['FOO=BAR', 'BAR=baz']
      redis_service.save
      expect {
        described_class.new(
            grid_service: redis_service,
            env: ['FOO=bar']
        ).run
      }.to change{ redis_service.reload.revision }.to(2)
    end

    it 'updates image' do
      redis_service.env = ['FOO=BAR', 'BAR=baz']
      redis_service.save
      expect {
        described_class.new(
            grid_service: redis_service,
            image: 'redis:3.0'
        ).run
      }.to change{ redis_service.reload.image_name }.to('redis:3.0')
    end

    it 'does not update revision when nothing changes' do
      redis_service.env = ['FOO=bar']
      redis_service.save
      expect {
        described_class.new(
            grid_service: redis_service,
            env: ['FOO=bar']
        ).run
      }.not_to change{ redis_service.reload.revision }
    end

    it 'updates affinity variables' do
      redis_service.affinity = ['az==a1', 'disk==ssd']
      redis_service.save
      expect {
        described_class.new(
            grid_service: redis_service,
            affinity: ['az==b1']
        ).run
      }.to change{ redis_service.reload.affinity }.to(['az==b1'])
    end

    it 'updates health check' do
      described_class.new(
          grid_service: redis_service,
          health_check: {
            port: 80,
            protocol: 'http'
          }
      ).run
      redis_service.reload
      expect(redis_service.health_check.port).to eq(80)
      expect(redis_service.health_check.protocol).to eq('http')
    end
  end

  describe '#build_grid_service_hooks' do
    let(:subject) do
      described_class.new(
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
      hooks = subject.build_grid_service_hooks([])
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

  describe '#build_grid_service_envs' do
    let(:redis_service) do
      GridService.create!(
        grid: grid,
        name: 'redis',
        image_name: 'redis:2.8',
        env: [
          'FOO=bar',
          'BAR=baz'
        ]
      )
    end
    let(:subject) do
      described_class.new(
        grid_service: redis_service
      )
    end

    it 'appends to env' do
      env = redis_service.env.dup
      env << 'TEST=test'
      env = subject.build_grid_service_envs(env)
      expect(env.size).to eq(3)
      expect(env[2]).to eq('TEST=test')
    end

    it 'modifies env' do
      env = redis_service.env.dup
      env[1] = 'BAR=bazzz'
      env = subject.build_grid_service_envs(env)
      expect(env.size).to eq(2)
      expect(env[1]).to eq('BAR=bazzz')
    end

    it 'does not modify env if value nil' do
      env = redis_service.env.dup
      env[1] = 'BAR='
      env = subject.build_grid_service_envs(env)
      expect(env.size).to eq(2)
      expect(env[1]).to eq('BAR=baz')
    end
  end
end

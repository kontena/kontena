require_relative '../../spec_helper'

describe Stacks::Deploy do
  let(:grid) { Grid.create!(name: 'test-grid') }

  let(:stack) {
    Stacks::Create.run(
      grid: grid,
      name: 'stack',
      stack: 'foo/bar',
      version: '0.1.0',
      registry: 'file://',
      source: '...',
      services: [{name: 'redis', image: 'redis:2.8', stateful: true }]
    ).result
  }

  before(:each) do
    Celluloid.boot
    Celluloid::Actor[:stack_deploy_worker] = StackDeployWorker.pool
  end

  after(:each) do
    Celluloid.shutdown
  end

  describe '#run' do
    it 'creates a stack deploy' do
      expect {
        described_class.run(stack: stack)
      }.to change{ stack.stack_deploys.count }.by(1)
    end

    it 'creates service deploys' do
      expect {
        described_class.run(stack: stack)
      }.to change{ GridServiceDeploy.count }.by(1)
    end

    it 'creates missing services' do
      Stacks::Update.run(
        stack_instance: stack,
        name: 'stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        services: [
          {name: 'redis', image: 'redis:2.8', stateful: true },
          {name: 'nginx', image: 'nginx:latest', stateful: false }
        ]
      )
      stack.grid_services.destroy_all
      expect {
        described_class.run(stack: stack)
      }.to change{ stack.grid_services.count }.by(2)
    end

    it 'removes services that are removed from a stack' do
      Stacks::Update.run(
        stack_instance: stack,
        name: 'stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        services: [
          {name: 'redis', image: 'redis:2.8', stateful: true },
          {name: 'nginx', image: 'nginx:latest', stateful: false }
        ]
      )
      Stacks::Update.run(
        stack_instance: stack,
        name: 'stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        services: [
          {name: 'nginx', image: 'nginx:latest', stateful: false }
        ]
      )
      redis = stack.grid_services.find_by(name: 'redis')
      mutation = described_class.new(stack: stack)
      expect(mutation).to receive(:remove_service).with(redis.id)
      mutation.run
    end
  end
end

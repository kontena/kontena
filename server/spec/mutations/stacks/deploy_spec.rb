
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

  let(:worker) { instance_double(StackDeployWorker) }
  let(:worker_async) { instance_double(StackDeployWorker) }

  before(:each) do
    allow_any_instance_of(described_class).to receive(:worker).with(:stack_deploy).and_return(worker)
    allow(worker).to receive(:async).and_return(worker_async)
  end

  describe '#run' do
    it 'creates a stack deploy' do
      expect(worker_async).to receive(:perform).once
      expect {
        described_class.run(stack: stack)
      }.to change{ stack.stack_deploys.count }.by(1)
    end

    it 'creates missing services' do
      Stacks::Update.run!(
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
      expect(worker_async).to receive(:perform).once
      expect {
        described_class.run(stack: stack)
      }.to change{ stack.grid_services.count }.by(2)
    end

    it 'updates services with volumes' do
      volume = Volume.create(grid: grid, name: 'vol', scope: 'instance', driver: 'local')

      Stacks::Update.run!(
        stack_instance: stack,
        name: 'stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        services: [
          {name: 'redis', image: 'redis:2.8', volumes: ['vol:/data'] }
        ],
        volumes: [
          {name: 'vol', external: 'vol'}
        ]
      )
      expect(worker_async).to receive(:perform).once
      outcome = described_class.run(stack: stack)
      expect(outcome.success?).to be_truthy
      redis = stack.reload.grid_services.find_by(name: 'redis')
      expect(redis.service_volumes.count).to eq(1)
      expect(redis.service_volumes.first.volume).to eq(volume)
    end
  end
end

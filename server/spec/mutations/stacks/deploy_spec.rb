
describe Stacks::Deploy, celluloid: true do
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
    Celluloid::Actor[:stack_deploy_worker] = StackDeployWorker.new
  end

  describe '#run' do
    it 'creates a stack deploy' do
      expect {
        described_class.run(stack: stack)
      }.to change{ stack.stack_deploys.count }.by(1)
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
      worker = Celluloid::Actor[:stack_deploy_worker]
      redis = stack.grid_services.find_by(name: 'redis')
      mutation = described_class.new(stack: stack)
      mutation.run
      sleep 0.01 until worker.mailbox.size == 0
      expect(GridService.find(redis.id)).to be_nil
    end

    it 'updates services with volumes' do
      volume = Volume.create(grid: grid, name: 'vol', scope: 'instance', driver: 'local')

      Stacks::Update.run(
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
      outcome = described_class.run(stack: stack)
      expect(outcome.success?).to be_truthy
      redis = stack.reload.grid_services.find_by(name: 'redis')
      expect(redis.service_volumes.count).to eq(1)
      expect(redis.service_volumes.first.volume).to eq(volume)
    end

    context "for a stack with externally linked services" do
      let(:stack) do
        Stacks::Create.run!(
          grid: grid,
          name: 'stack',
          stack: 'foo/bar',
          version: '0.1.0',
          registry: 'file://',
          source: '...',
          services: [
            {name: 'foo', image: 'redis', stateful: false },
            {name: 'bar', image: 'redis', stateful: false },
          ]
        )
      end

      let(:linking_service) do
        GridServices::Create.run!(
          grid: grid,
          stack: stack,
          name: 'asdf',
          image: 'redis',
          stateful: false,
          links: [
            {name: 'stack/bar', alias: 'bar'},
          ],
        )
      end

      it 'does not remove a linked service' do
        linking_service
        expect(stack.grid_services.find_by(name: 'bar').linked_from_services.to_a).to_not be_empty

        Stacks::Update.run(
          stack_instance: stack,
          name: 'stack',
          stack: 'foo/bar',
          version: '0.1.0',
          registry: 'file://',
          source: '...',
          services: [
            {name: 'foo', image: 'redis', stateful: false },
          ],
        )

        expect(outcome = described_class.run(stack: stack)).to be_success

        worker = Celluloid::Actor[:stack_deploy_worker]
        sleep 0.01 until worker.mailbox.size == 0

        stack_deploy = outcome.result.reload

        expect(stack_deploy).to be_error # XXX: where does the error message go?
      end
    end
  end
end

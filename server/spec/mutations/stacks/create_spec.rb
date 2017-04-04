
describe Stacks::Create do
  let(:grid) { Grid.create!(name: 'test-grid') }

  describe '#run' do
    it 'creates a new grid stack' do
      grid
      expect {
        outcome = described_class.new(
          grid: grid,
          name: 'stack',
          stack: 'foo/bar',
          version: '0.1.0',
          registry: 'file://',
          source: '...',
          variables: {foo: 'bar'},
          services: [{name: 'redis', image: 'redis:2.8', stateful: true }]
        ).run

        expect(outcome).to be_success
      }.to change{ Stack.count }.by(1)
    end

    it 'creates stack revision' do
      outcome = described_class.new(
        grid: grid,
        name: 'stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        variables: {foo: 'bar'},
        services: [{name: 'redis', image: 'redis:2.8', stateful: true }]
      ).run
      expect(outcome).to be_success
      expect(outcome.result.stack_revisions.count).to eq(1)
    end

    it 'creates stack services' do
      outcome = described_class.new(
        grid: grid,
        name: 'stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        variables: {foo: 'bar'},
        services: [{name: 'redis', image: 'redis:2.8', stateful: true }]
      ).run
      expect(outcome).to be_success
      expect(outcome.result.grid_services.count).to eq(1)
    end

    it 'allows - char in name' do
      outcome = described_class.new(
        grid: grid,
        name: 'soome-stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        variables: {foo: 'bar'},
        services: [{name: 'redis', image: 'redis:2.8', stateful: true }]
      ).run
      expect(outcome).to be_success
    end

    it 'allows numbers in name' do
      outcome = described_class.new(
        grid: grid,
        name: 'stack-12',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        variables: {foo: 'bar'},
        services: [{name: 'redis', image: 'redis:2.8', stateful: true }]
      ).run
      expect(outcome).to be_success
    end

    it 'does not allow - as a first char in name' do
      outcome = described_class.new(
        grid: grid,
        name: '-stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        variables: {foo: 'bar'},
        services: [{name: 'redis', image: 'redis:2.8', stateful: true }]
      ).run
      expect(outcome).to_not be_success
      expect(outcome.errors.message.keys).to include('name')
    end

    it 'does not allow special chars in name' do
      outcome = described_class.new(
        grid: grid,
        name: 'red&is',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        variables: {foo: 'bar'},
        services: [{name: 'redis', image: 'redis:2.8', stateful: true }]
      ).run
      expect(outcome).to_not be_success
      expect(outcome.errors.message.keys).to include('name')
    end

    it 'does not allow empty services array' do
      outcome = described_class.new(
        grid: grid,
        name: 'redis',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        variables: {foo: 'bar'},
        services: []
      ).run
      expect(outcome).to_not be_success
      expect(outcome.errors.message.keys).to include('services')
    end

    it 'creates new service linked to stack' do
      services = [{name: 'redis', image: 'redis:2.8', stateful: true }]
      outcome = described_class.new(
        grid: grid,
        name: 'soome-stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        variables: {foo: 'bar'},
        services: services
      ).run

      expect(outcome).to be_success
      expect(outcome.result.stack_revisions.count).to eq(1)
    end

    it 'creates stack with linked services' do
      services = [
        {
          name: 'redis',
          image: 'redis:2.8',
          stateful: true
        },
        {
          name: 'api',
          image: 'myapi:latest',
          stateful: false,
          links: [
            {name: 'redis', alias: 'redis'}
          ]
        }
      ]
      outcome = described_class.new(
        grid: grid,
        name: 'soome-stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        variables: {foo: 'bar'},
        services: services
      ).run
      expect(outcome).to be_success
      expect(outcome.result.stack_revisions.count).to eq(1)
    end

    it 'fails if link to another stack is invalid' do
      services = [
        {
          name: 'api',
          image: 'myapi:latest',
          stateful: false,
          links: [
            {name: 'redis/redis', alias: 'redis'}
          ]
        }
      ]
      outcome = described_class.new(
        grid: grid,
        name: 'soome-stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        variables: {foo: 'bar'},
        services: services
      ).run
      expect(outcome).to_not be_success
      expect(outcome.errors.message).to eq 'services' => { 'api' => { 'links' => [ "Link redis/redis points to non-existing stack" ] } }
    end

    it 'fails if link within a stack is invalid' do
      services = [
        {
          name: 'api',
          image: 'myapi:latest',
          stateful: false,
          links: [
            {name: 'redis', alias: 'redis'}
          ]
        }
      ]
      outcome = described_class.new(
        grid: grid,
        name: 'soome-stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        variables: {foo: 'bar'},
        services: services
      ).run
      expect(outcome).to_not be_success
      expect(outcome.errors.message).to eq 'services' => { 'api' => { 'links' => [ "Linked service 'redis' does not exist" ] } }
    end

    it 'does not create stack if any service validation fails' do
      services = [
        {grid: grid, name: 'redis', image: 'redis:2.8', stateful: true },
        {grid: grid, name: 'invalid'}
      ]
      expect {
        outcome = described_class.new(
          grid: grid,
          name: 'soome-stack',
          stack: 'foo/bar',
          version: '0.1.0',
          registry: 'file://',
          source: '...',
          variables: {foo: 'bar'},
          services: services
        ).run
        expect(outcome.success?).to be(false)
      }.to change{ grid.stacks.count }.by(0)
    end

    it 'does not create stack if exposed service does not exist' do
      services = [
        {grid: grid, name: 'redis', image: 'redis:2.8', stateful: true }
      ]
      expect {
        outcome = described_class.new(
          grid: grid,
          name: 'redis',
          stack: 'foo/bar',
          version: '0.1.0',
          registry: 'file://',
          source: '...',
          variables: {foo: 'bar'},
          expose: 'foo',
          services: services
        ).run
        expect(outcome).to_not be_success
      }.to change{ grid.stacks.count }.by(0)
    end

    it 'reports multiple service create errors' do
      services = [
        {
          name: 'foo',
          image: 'foo:latest',
          stateful: false,
        },
        {
          name: 'bar',
          image: 'bar:latest',
          stateful: false,
          links: [
            { 'name' => 'foo', 'alias' => 'foo' }
          ]
        },
      ]

      foo_errors = Mutations::ErrorHash.new
      foo_errors[:name] = Mutations::ErrorAtom.new(:name, :create, message: "Create failed")
      bar_errors = Mutations::ErrorHash.new
      bar_errors[:links] = Mutations::ErrorAtom.new(:links, :exist, message: "Service soome-stack/foo does not exist")

      expect(GridServices::Create).to receive(:run).with(hash_including("name" => 'foo')).and_return(Mutations::Outcome.new(false, nil, foo_errors, {}))
      expect(GridServices::Create).to receive(:run).with(hash_including("name" => 'bar')).and_return(Mutations::Outcome.new(false, nil, bar_errors, {}))

      outcome = described_class.new(
        grid: grid,
        name: 'soome-stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        variables: {foo: 'bar'},
        services: services
      ).run
      expect(outcome).to_not be_success
      expect(outcome.errors.message).to eq 'services' => { 'foo' => {'name' => "Create failed"}, 'bar' => { 'links' => "Service soome-stack/foo does not exist"}}
    end

    context 'volumes' do
      it 'creates stack with external volumes with name' do
        volume = Volume.create(name: 'someVolume', grid: grid, scope: 'node')
        outcome = described_class.new(
          grid: grid,
          name: 'stack',
          stack: 'foo/bar',
          version: '0.1.0',
          registry: 'file://',
          source: '...',
          variables: {foo: 'bar'},
          services: [{name: 'redis', image: 'redis:2.8', stateful: true, volumes: ['vol1:/data'] }],
          volumes: [{name: 'vol1', external: 'someVolume'}]
        ).run
        expect(outcome.success?).to be_truthy
        redis = outcome.result.grid_services.first
        expect(outcome.result.latest_rev.volumes.size).to eq(1)
        expect(redis.service_volumes.first.volume).to eq(volume)
      end
    end

    it 'fails to create stack when external volume does not exist' do

      outcome = described_class.new(
        grid: grid,
        name: 'stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        variables: {foo: 'bar'},
        services: [{name: 'redis', image: 'redis:2.8', stateful: true }],
        volumes: [{name: 'vol1', external: 'foo'}]
      ).run
      expect(outcome).not_to be_success

    end

    it 'fails to create stack with unsupported volume definition' do
      outcome = described_class.new(
        grid: grid,
        name: 'stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        variables: {foo: 'bar'},
        services: [{name: 'redis', image: 'redis:2.8', stateful: true }],
        volumes: [{name: 'vol1', driver: 'foo', scope: 'foobar'}]
      ).run
      expect(outcome.success?).to be_falsey

    end
  end
end

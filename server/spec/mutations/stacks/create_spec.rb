
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

    it 'creates a new grid stack with parent' do
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
          services: [{name: 'redis', image: 'redis:2.8', stateful: true }],
          parent_name: 'stack-parent'
        ).run

        expect(outcome).to be_success
        expect(outcome.result.parent_name).to eq 'stack-parent'
        expect(outcome.result.has_parent?).to be_truthy
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

    it 'does not allow newlines in name' do
      outcome = described_class.new(
        grid: grid,
        name: "foo\nbar",
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        variables: {foo: 'bar'},
        services: [{name: 'redis', image: 'redis:2.8', stateful: true }]
      ).run
      expect(outcome).to_not be_success
      expect(outcome.errors.symbolic).to eq 'name' => :matches
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

    it 'does not allow a service name that is too long for the stack' do
      outcome = described_class.new(
        grid: grid,
        name: 'foo',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        variables: {foo: 'bar'},
        services: [{name: 'xxxxxxxx10xxxxxxxx20xxxxxxxx30xxxx36', image: 'redis:2.8', stateful: true }]
      ).run
      expect(outcome).to_not be_success
      expect(outcome.errors.message).to eq 'services' => { 'xxxxxxxx10xxxxxxxx20xxxxxxxx30xxxx36' => { 'name' => 'Total grid service name length 66 is over limit (64): xxxxxxxx10xxxxxxxx20xxxxxxxx30xxxx36-1.foo.test-grid.kontena.local' } }
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
            {'name' => 'redis', 'alias' => 'redis'}
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

    it 'creates stack with complex linked services in the correct order' do
      services = [
        {
          name: 'bar',
          image: 'bar:latest',
          stateful: false,
          links: [
            {'name' => 'foo', 'alias' => 'api'}
          ]
        },
        {
          name: 'foo',
          image: 'foo:latest',
          stateful: true,
          links: [
            {'name' => 'asdf', 'alias' => 'api'}
          ]
        },
        {
          name: 'asdf',
          image: 'asdf:latest',
          stateful: true,
          links: [
            {'name' => 'asdf1', 'alias' => 'asdf1'},
            {'name' => 'asdf2', 'alias' => 'asdf2'},
            {'name' => 'asdf3', 'alias' => 'asdf3'},
          ]
        },
        {
          name: 'asdf1',
          image: 'asdf:latest',
          stateful: true,
        },
        {
          name: 'asdf2',
          image: 'asdf:latest',
          stateful: true,
        },
        {
          name: 'asdf3',
          image: 'asdf:latest',
          stateful: true,
        },
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
      expect(outcome).to be_success, outcome.errors
      expect(outcome.result.stack_revisions.count).to eq(1)
    end

    it 'does not create a stack if link to another stack is invalid' do
      services = [
        {
          name: 'api',
          image: 'myapi:latest',
          stateful: false,
          links: [
            {'name' => 'redis/redis', 'alias' => 'redis'}
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
            {'name' => 'redis', 'alias' => 'redis'}
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
      expect(outcome.errors.message).to eq 'services' => { 'api' => { 'links' => "service api has missing links: redis" } }
      expect(outcome.errors.symbolic).to eq 'services' => { 'api' => { 'links' => :missing } }
    end

    it 'fails and does not create stack if a service links to itself' do
      services = [
        {
          name: 'api',
          image: 'myapi:latest',
          stateful: false,
          links: [
            {'name' => 'api', 'alias' => 'api'}
          ]
        }
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
        expect(outcome).to_not be_success
        expect(outcome.errors.message).to eq 'services' => { 'api' => { 'links' => 'service api has recursive links: ["api", [...]]' } }
        expect(outcome.errors.symbolic).to eq 'services' => { 'api' => { 'links' => :recursive } }
      }.to not_change{ grid.stacks.count }
    end

    it 'fails and does not create stack if services have recursive links' do
      services = [
        {
          name: 'api',
          image: 'myapi:latest',
          stateful: false,
          links: [
            {'name' => 'bar', 'alias' => 'bar'}
          ]
        },
        {
          name: 'bar',
          image: 'myapi:latest',
          stateful: false,
          links: [
            {'name' => 'api', 'alias' => 'api'}
          ]
        }
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
        expect(outcome).to_not be_success
        expect(outcome.errors.message).to eq 'services' => { 'api' => { 'links' => 'service api has recursive links: ["bar", ["api", [...]]]' } }
        expect(outcome.errors.symbolic).to eq 'services' => { 'api' => { 'links' => :recursive } }
      }.to not_change{ grid.stacks.count }
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
      }.to not_change{ grid.stacks.count }
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
      }.to not_change{ grid.stacks.count }
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

    it 'reports service error array outcomes' do
      services = [
        {grid: grid, name: 'redis', image: 'redis:2.8', stateful: true,
          env: [
            'FOO',
          ],
        }
      ]
      expect {
        outcome = described_class.new(
          grid: grid,
          name: 'redis',
          stack: 'foo/bar',
          version: '0.1.0',
          registry: 'file://',
          source: '...',
          services: services
        ).run
        expect(outcome).to_not be_success
        expect(outcome.errors.message).to eq 'services' => { 'redis' => {'env' => [ "Env[0] isn't in the right format" ]}}
      }.to_not change{ grid.stacks.count }
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
      expect(outcome.errors.message).to eq({'volumes' => {'vol1' => { 'external' => "External volume foo not found"}}})

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
      expect(outcome).not_to be_success
      expect(outcome.errors.message).to eq({'volumes' => {'vol1' => "Only external volumes supported"}})

    end
  end

  context "with an external stack" do
    let(:stack2) do
      Stacks::Create.run!(
        grid: grid,
        name: 'stack2',
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

    let(:stack2_services_foo) do
      stack2.grid_services.find_by(name: 'foo')
    end

    before do
      stack2
    end

    it 'creates stack with external links' do
      services = [
        {
          name: 'redis',
          image: 'redis:2.8',
          stateful: true,
          links: [
            {'name' => 'stack2/foo', 'alias' => 'foo'}
          ]
        }
      ]
      outcome = described_class.new(
        grid: grid,
        name: 'some-stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        variables: {foo: 'bar'},
        services: services
      ).run

      expect(outcome).to be_success
      expect(outcome.result.stack_revisions.count).to eq(1)
      expect(outcome.result.grid_services.find_by(name: 'redis').grid_service_links.map{|l| l.linked_grid_service}).to eq [stack2_services_foo]
    end
  end
end

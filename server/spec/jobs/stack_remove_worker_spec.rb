
describe StackRemoveWorker do
  before(:each) do
    Celluloid.boot
  end

  after(:each) do
    Celluloid.shutdown
  end

  let :grid do
    Grid.create(name: 'test')
  end

  let :default_stack do
    grid.stacks.find_by(name: Stack::NULL_STACK)
  end

  let :lb_service do
    GridService.create(grid: grid, stack: default_stack, name: 'lb', image_name: 'kontena/lb:latest')
  end

  let :stack do
    lb_service

    Stacks::Create.run!(
      grid: grid,
      name: 'stack',
      stack: 'foo/bar',
      version: '0.1.0',
      registry: 'file://',
      source: '...',
      services: [
        {name: 'redis', image: 'redis:2.8', stateful: true, links: [
          { name: "null/lb", alias: 'lb' },
        ] },
      ],
    )
  end

  let :redis_service do
    stack.grid_services.first
  end

  let :outcome_success do
    double(success?: true)
  end

  before do
    expect(redis_service.grid_service_links.map {|l| l.linked_grid_service.name}).to eq ['lb']
  end

  context "For a stack with linked services" do
    let :foo_service do
      GridServices::Create.run!(
        grid: grid,
        stateful: false,
        name: 'foo',
        image: 'foo:latest',
        stack: stack,
        links: [
          { name: 'redis', alias: 'redis' }
        ]
      )
    end

    let :bar_service do
      GridServices::Create.run!(
        grid: grid,
        stateful: false,
        name: 'bar',
        image: 'bar:latest',
        stack: stack,
        links: [
          { name: 'redis', alias: 'redis' }
        ]
      )
    end

    describe '#sort_services' do
      it "Sorts the services in reverse-dependency order" do
        # assume stable sort
        expect(subject.sort_services([redis_service, foo_service, bar_service]).reverse).to eq [bar_service, foo_service, redis_service]
      end

      it "Sorts the services in reverse-dependency order when the linked-to service is after the linking service" do
        expect(subject.sort_services([foo_service, redis_service, bar_service]).reverse).to eq [bar_service, foo_service, redis_service]
      end
    end
  end
end

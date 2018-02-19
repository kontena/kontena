
describe Stacks::Delete, celluloid: true do
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:stack) { Stack.create!(grid: grid, name: 'stack') }
  let(:default_stack) { grid.stacks.find_by(name: Stack::NULL_STACK) }

  subject { described_class.new(stack: stack) }

  context "for a stack with linked services" do
    let(:redis_service) { GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8', stack: stack) }

    let(:foo_service) { GridService.create(grid: grid, name: 'foo', stack: stack,
      image_name: 'redis:2.8',
    )}
    let(:bar_service) { GridService.create(grid: grid, name: 'bar', stack: stack,
      image_name: 'redis:2.8',
    )}

    before do
      foo_service.link_to(redis_service)
      bar_service.link_to(redis_service)

      # XXX: mongoid has a bug where it sets grid_service_links on the linked-to service
      redis_service.reload
    end

    describe '#sort_services' do
      it "sorts the services in reverse-dependency order" do
        # assume stable sort
        expect(subject.sort_services([redis_service, foo_service, bar_service]).reverse).to eq [bar_service, foo_service, redis_service]
      end

      it "sorts the services in reverse-dependency order when the linked-to service is after the linking service" do
        expect(subject.sort_services([foo_service, redis_service, bar_service]).reverse).to eq [bar_service, foo_service, redis_service]
      end
    end
  end

  context "for the default stack" do
    subject { described_class.new(stack: default_stack) }

    it 'fails' do
      outcome = subject.run

      expect(outcome).to_not be_success
      expect(outcome.errors.message).to eq 'stack' => "Cannot delete default stack"
    end
  end

  context "for a stack with a single service" do
    let(:redis_service) { GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8', stack: stack) }

    it "removes the stack services and stack" do
      expect{
        outcome = subject.run

        expect(outcome).to be_success
      }.to change{GridService.where(stack: stack).to_a}.from([redis_service]).to([])
      .and change{Stack.find_by(id: stack.id)}.from(stack).to(nil)
    end
  end

  context "for a stack with links within the stack" do
    let!(:redis_service) { GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8', stack: stack) }
    let!(:web_service) { GridService.create(grid: grid, name: 'web', image_name: 'web:latest', stack: stack,
      grid_service_links: [ GridServiceLink.new(linked_grid_service: redis_service) ],
    ) }

    before do
      web_service.link_to(redis_service)

      # XXX: mongoid has a bug where it sets grid_service_links on the linked-to service
      redis_service.reload
    end

    it "removes the stack services" do
      expect{
        outcome = subject.run

        expect(outcome).to be_success
      }.to change{GridService.where(stack: stack).to_a}.to([])
      .and change{Stack.find_by(id: stack.id)}.to(nil)
    end
  end

  context "for a stack with links outside the stack" do
    let!(:lb_service) { GridService.create(grid: grid, stack: default_stack, name: 'lb', image_name: 'kontena/lb:latest') }
    let!(:web_service) { GridService.create(grid: grid, name: 'web', image_name: 'web:latest', stack: stack,
    ) }

    before do
      web_service.link_to(lb_service)

      # XXX: mongoid has a bug where it sets grid_service_links on the linked-to service
      lb_service.reload
    end

    it "removes the stack services" do
      expect{
        outcome = subject.run

        expect(outcome).to be_success
      }.to change{GridService.where(stack: stack).to_a}.to([])
      .and change{Stack.find_by(id: stack.id)}.to(nil)
    end
  end

  context "for a stack with links to the stack" do
    let!(:redis_service) { GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8', stack: stack) }
    let!(:web_service) { GridService.create(grid: grid, name: 'web', image_name: 'web:latest', stack: default_stack,
      grid_service_links: [ GridServiceLink.new(linked_grid_service: redis_service) ],
    ) }

    before do
      web_service.link_to(redis_service)

      # XXX: mongoid has a bug where it sets grid_service_links on the linked-to service
      redis_service.reload
    end

    it "does not allow removing the stack" do
      expect{
        outcome = subject.run

        expect(outcome).to_not be_success
      }.to_not change{GridService.where(stack: stack).to_a}.from([redis_service])
    end
  end
end

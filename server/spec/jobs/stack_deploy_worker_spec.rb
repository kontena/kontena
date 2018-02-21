
describe StackDeployWorker, celluloid: true do

  let(:grid) { Grid.create(name: 'test') }

  let(:stack) do
    Stacks::Create.run(
      grid: grid,
      name: 'stack',
      stack: 'foo/bar',
      version: '0.1.0',
      registry: 'file://',
      source: '...',
      services: [{name: 'redis', image: 'redis:2.8', stateful: true }]
    ).result
  end

  let(:stack_deploy) { stack.stack_deploys.create! }
  let(:stack_rev) { stack.latest_rev }
  let(:service) { stack.grid_services.first }

  describe '#deploy_stack' do
    it 'changes stack_deploy state to success' do
      expect(GridServices::Deploy).to receive(:run).with(grid_service: service) do
        double(success?: true, result: GridServiceDeploy.create!(grid_service: service,
          started_at: Time.now - 5.0,
          finished_at: Time.now - 1.0,
          deploy_state: :success,
        ))
      end

      expect{
        subject.deploy_stack(stack_deploy, stack_rev)
      }.to change{stack_deploy.reload.state}.from(:created).to(:success)
    end

    it 'changes state to error when deploy mutation fails' do
      expect(GridServices::Deploy).to receive(:run).with(grid_service: service) do
        double(success?: false, errors: double(message: { 'image' => "Invalid image" }))
      end

      expect{
        subject.deploy_stack(stack_deploy, stack_rev)
      }.to change{stack_deploy.reload.state}.from(:created).to(:error).and raise_error(RuntimeError)
    end

    it 'changes state to error when deploy fails' do
      expect(GridServices::Deploy).to receive(:run).with(grid_service: service) do
        double(success?: true, result: GridServiceDeploy.create!(grid_service: service,
          started_at: Time.now - 5.0,
          finished_at: Time.now - 1.0,
          deploy_state: :error,
        ))
      end

      expect{
        subject.deploy_stack(stack_deploy, stack_rev)
      }.to change{stack_deploy.reload.state}.from(:created).to(:error).and raise_error(RuntimeError)
    end
  end

  describe '#remove_services' do
    it 'does not remove anything if stack rev has stayed the same' do
      stack_rev = stack.latest_rev
      expect(GridServices::Delete).not_to receive(:run)
      expect {
        subject.remove_services(stack, stack_rev)
      }.not_to change{ stack.grid_services.to_a }
    end

    it 'does not remove anything if stack rev has additional services' do
      Stacks::Update.run!(
        stack_instance: stack,
        name: 'stack',
        stack: 'foo/bar',
        version: '0.1.1',
        registry: 'file://',
        source: '...',
        services: [
          {name: 'redis', image: 'redis:2.8', stateful: true },
          {name: 'lb', image: 'kontena/lb:latest', stateful: false }
        ]
      )

      stack_rev = stack.latest_rev
      expect(GridServices::Delete).not_to receive(:run)
      expect {
        subject.remove_services(stack, stack_rev)
      }.not_to change{ stack.grid_services.to_a }
    end

    it 'removes services that are gone from latest stack rev' do
      outcome = Stacks::Create.run(
        grid: grid,
        name: 'stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        services: [
          {name: 'redis', image: 'redis:2.8', stateful: true },
          {name: 'lb', image: 'kontena/lb:latest', stateful: false }
        ]
      )
      expect(outcome.success?).to be_truthy
      stack = outcome.result
      lb = stack.grid_services.find_by(name: 'lb')
      Stacks::Update.run(
        stack_instance: stack,
        name: 'stack',
        stack: 'foo/bar',
        version: '0.1.1',
        registry: 'file://',
        source: '...',
        services: [
          {name: 'redis', image: 'redis:2.8', stateful: true }
        ]
      )
      stack_rev = stack.latest_rev
      expect {
        subject.remove_services(stack, stack_rev)
      }.to change { stack.grid_services.find_by(name: 'lb') }.from(lb).to(nil)
    end
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

    describe '#remove_services' do
      it 'fails if removing a linked service' do
        Stacks::Update.run!(
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

        # link to the service after the update, but before the deploy
        linking_service
        expect(stack.grid_services.find_by(name: 'bar').linked_from_services.to_a).to_not be_empty

        stack_rev = stack.latest_rev
        expect {
          subject.remove_services(stack, stack_rev)
        }.to raise_error(RuntimeError, 'service test/stack/bar remove failed: {"service"=>"Cannot delete service that is linked to another service (asdf)"}').and not_change { stack.grid_services.count }
      end
    end
  end
end

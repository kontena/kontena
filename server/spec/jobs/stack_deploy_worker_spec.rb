
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

  describe '#deploy_stack' do
    it 'changes stack_deploy state to success' do
      stack_deploy = stack.stack_deploys.create
      stack_rev = stack.latest_rev

      deploy_result = double(:result, :success? => true, :error? => false)
      allow(subject.wrapped_object).to receive(:deploy_service).and_return(deploy_result)
      stack_deploy = subject.deploy_stack(stack_deploy, stack_rev)
      expect(stack_deploy.success?).to be_truthy
    end

    it 'changes state to error when deploy fails' do
      stack_deploy = stack.stack_deploys.create
      stack_rev = stack.latest_rev

      deploy_result = double(:result, :success? => false, :error? => true)
      allow(subject.wrapped_object).to receive(:deploy_service).and_return(deploy_result)
      stack_deploy = subject.deploy_stack(stack_deploy, stack_rev)
      expect(stack_deploy.error?).to be_truthy
    end
  end

  describe '#remove_services' do
    it 'does not remove anything if stack rev has stayed the same' do
      stack_rev = stack.latest_rev
      expect(subject.wrapped_object).not_to receive(:remove_service)
      subject.remove_services(stack, stack_rev)
    end

    it 'does not remove anything if stack rev has additional services' do
      outcome = Stacks::Update.run(
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
      expect(outcome.success?).to be_truthy
      stack_rev = stack.latest_rev
      expect(subject.wrapped_object).not_to receive(:remove_service)
      subject.remove_services(stack, stack_rev)
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
      expect(subject.wrapped_object).to receive(:remove_service).once.with(lb.id)
      subject.remove_services(stack, stack_rev)
    end
  end

  describe '#remove_service' do
    it 'calls service remove worker' do
      expect(subject.respond_to?(:worker)).to be_truthy
      expect(subject.wrapped_object).to receive(:worker).with(:grid_service_remove).and_return(spy)
      subject.remove_service('foo')
    end
  end
end

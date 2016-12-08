require_relative '../spec_helper'

describe StackDeployWorker do

  before(:each) do
    Celluloid.boot
  end

  after(:each) do
    Celluloid.shutdown
  end

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
end

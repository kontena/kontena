require_relative '../../spec_helper'

describe Stacks::Update do
  let(:user) { User.create!(email: 'joe@domain.com')}

  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << user
    grid
  }

  let(:stack) {
    stack = Stack.create!(grid: grid, name: 'stack')
    redis = GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8', stack: stack)
    stack
  }

  describe '#run' do
    it 'updates stack and creates a new revision' do
      services = [{name: 'redis', image: 'redis:3.0'}]
      subject = described_class.new(current_user: user, stack: stack, services: services)
      outcome = subject.run
      expect(outcome.success?).to be_truthy
      expect(outcome.result.stack_revisions.count).to eq(1)
      expect(stack.reload.grid_services.first.image_name).to eq('redis:2.8')
    end

    it 'does not increase version automatically' do
      services = [{name: 'redis', image: 'redis:3.0'}]
      subject = described_class.new(current_user: user, stack: stack, services: services)
      expect {
        outcome = subject.run
        expect(outcome.success?).to be_truthy
      }.not_to change{ stack.reload.version }
    end

    it 'updates and creates new services' do
      services = [
        {name: 'redis', image: 'redis:3.0'},
        {name: 'foo', image: 'redis:3.0', stateful: true}
      ]
      subject = described_class.new(current_user: user, stack: stack, services: services)
      expect {
        outcome = subject.run
        expect(outcome.success?).to be_truthy
      }.to change{ stack.stack_revisions.count }.by(1)
    end
  end
end

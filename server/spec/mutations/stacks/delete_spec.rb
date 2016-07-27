require_relative '../../spec_helper'

describe Stacks::Delete do
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << user
    grid
  }
  let(:stack) {
    stack = Stack.create!(grid: grid, name: 'stack')
    redis = GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8', stack: stack)
    web = GridService.create(grid: grid, name: 'web', image_name: 'web:latest', stack: stack)
    stack.reload
  }

  describe '#run' do
    it 'calls grid_service delete mutation' do
      oc = spy
      allow(oc).to receive(:success?).and_return(true)
      expect(GridServices::Delete).to receive(:run).exactly(2).times.and_return(spy)
      stack
      expect {
        outcome = described_class.run(current_user: user, stack: stack)
        expect(outcome.success?).to be_truthy
      }.to change{ Stack.count }.by(-1)
    end

    it 'does not call grid_service delete mutation when validation fails' do
      mutation = described_class.new(current_user: user, stack: stack)
      allow(mutation).to receive(:has_errors?).and_return(true)
      expect(GridServices::Delete).not_to receive(:run)
      outcome = mutation.run
      expect(outcome.success?).to be_falsey
    end

    it 'allows to remove stack that has links within stack' do
      foo = GridServices::Create.run(
        grid: grid, current_user: user, stateful: false,
        name: 'foo', image: 'foo:latest', stack: stack,
        links: [
          { name: 'stack/web', alias: 'web' }
        ]
      )
      expect(GridServices::Delete).to receive(:run).exactly(stack.grid_services.count).
        times.and_return(spy())
      outcome = described_class.run(current_user: user, stack: stack)
      expect(outcome.success?).to be_truthy
    end

    it 'does not allow to remove stack that has linked from other stacks' do
      default_stack = grid.stacks.find_by(name: 'default')
      stack
      foo = GridServices::Create.run(
        grid: grid, current_user: user, stateful: false,
        name: 'foo', image: 'foo:latest', stack: default_stack,
        links: [
          { name: 'stack/web', alias: 'web' }
        ]
      )
      expect(GridServices::Delete).not_to receive(:run)
      outcome = described_class.run(current_user: user, stack: stack)
      expect(outcome.success?).to be_falsey
    end
  end
end

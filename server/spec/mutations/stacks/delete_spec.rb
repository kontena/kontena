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
      expect(GridServices::Delete).to receive(:validate).exactly(2).times.and_return(oc)
      expect(GridServices::Delete).to receive(:run).exactly(2).times.and_return(spy)
      outcome = described_class.run(current_user: user, stack: stack)
      
      expect(outcome.success?).to be_truthy
      expect(stack.reload.terminated?).to be_truthy
    end

    it 'does not call grid_service delete mutation when validation fails' do
      oc = spy
      allow(oc).to receive(:success?).and_return(false)
      expect(GridServices::Delete).to receive(:validate).exactly(2).times.and_return(oc)
      expect(GridServices::Delete).not_to receive(:run)
      
      outcome = described_class.run(current_user: user, stack: stack)
      
      expect(outcome.success?).to be_falsey
      expect(stack.reload.terminated?).to be_falsey
    end

    it 'fails if stack is already terminated' do
      stack.state = :terminated
      subject = described_class.new(current_user: user, stack: stack)
      expect(GridServices::Delete).not_to receive(:run)
      outcome = subject.run
      expect(outcome.success?).to be_falsey
      expect(outcome.errors.message).to eq({"stack" => "Stack already terminated"})
    end

  end
end

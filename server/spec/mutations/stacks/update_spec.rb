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
    it 'updates services' do
      services = [{grid: grid, name: 'redis', image: 'redis:3.0'}]
      subject = described_class.new(current_user: user, stack: stack, services: services)
      outcome = subject.run
      expect(outcome.success?).to be_truthy
      expect(stack.reload.grid_services.first.image_name).to eq('redis:3.0')
    end

    it 'fails if stack is already terminated' do
      stack.state = :terminated
      subject = described_class.new(current_user: user, stack: stack)
      expect(subject).not_to receive(:worker)
      outcome = subject.run
      expect(outcome.success?).to be_falsey
      expect(outcome.errors.message).to eq({"stack" => "Stack already terminated"})

    end

    it 'updates and creates new services' do
      services = [
        {grid: grid, name: 'redis', image: 'redis:3.0'},
        {grid: grid, name: 'foo', image: 'redis:3.0', stateful: true}
      ]
      subject = described_class.new(current_user: user, stack: stack, services: services)
      outcome = subject.run
      puts "ERROR: #{outcome.errors.message}" unless outcome.success?
      expect(outcome.success?).to be_truthy
      expect(stack.reload.grid_services.count).to eq(2)
    end

    it 'deletes services' do
      outcome = spy
      expect(GridServices::Delete).to receive(:run).and_return(outcome)
      allow(outcome).to receive(:success?).and_return(true)
      subject = described_class.new(current_user: user, stack: stack, services: [])
      real_outcome = subject.run
      expect(real_outcome.success?).to be_truthy
    end

  end
end


describe Stacks::Delete, celluloid: true do
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:stack) {
    stack = Stack.create!(grid: grid, name: 'stack')
    redis = GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8', stack: stack)
    web = GridService.create(grid: grid, name: 'web', image_name: 'web:latest', stack: stack)
    stack.reload
  }
  let(:default_stack) { grid.stacks.find_by(name: Stack::NULL_STACK) }
  let(:worker_klass) do
    Class.new do
      include Celluloid

      attr_reader :performed

      def initialize
        @performed = nil
      end

      def perform(id)
        @performed = id
      end
    end
  end
  let(:worker) do
    worker = worker_klass.new
    Celluloid::Actor[:stack_remove_worker] = worker
    worker
  end

  describe '#run' do
    it 'calls stack remove worker' do
      worker
      outcome = described_class.run(stack: stack)
      expect(outcome.success?).to be_truthy
      sleep 0.01 until worker.performed
      expect(worker.performed).to eq(stack.id)
    end

    it 'allows to remove stack that has links within stack' do
      foo = GridServices::Create.run(
        grid: grid, stateful: false,
        name: 'foo', image: 'foo:latest', stack: stack,
        links: [
          { name: 'stack/web', alias: 'web' }
        ]
      )
      worker
      outcome = described_class.run(stack: stack)
      expect(outcome.success?).to be_truthy
      sleep 0.01 until worker.performed
      expect(worker.performed).to eq(stack.id)
    end

    it 'does not allow to remove default stack' do
      mutation = described_class.new(stack: default_stack)
      outcome = mutation.run
      expect(outcome.success?).to be_falsey
    end

    it 'does not allow to remove stack that has linked from other stacks' do
      default_stack = grid.stacks.find_by(name: Stack::NULL_STACK)
      stack
      foo = GridServices::Create.run(
        grid: grid, stateful: false,
        name: 'foo', image: 'foo:latest', stack: default_stack,
        links: [
          { name: 'stack/web', alias: 'web' }
        ]
      )
      outcome = described_class.run(stack: stack)
      expect(outcome.success?).to be_falsey
    end
  end
end

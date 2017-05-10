describe Stacks::Restart do
  let(:grid) { Grid.create!(name: 'test-grid') }

  let(:stack) {
    Stacks::Create.run(
      grid: grid,
      name: 'stack',
      stack: 'foo/bar',
      version: '0.1.0',
      registry: 'file://',
      source: '...',
      services: [{name: 'redis', image: 'redis:2.8', stateful: true }, {name: 'redis2', image: 'redis:2.8', stateful: true }]
    ).result
  }

  describe '#run' do
    it 'stops all services in stack' do
      expect(GridServices::Restart).to receive(:run).twice

      described_class.run(stack: stack)
    end
  end

end
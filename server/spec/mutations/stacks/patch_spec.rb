
describe Stacks::Patch do
  let(:grid) { Grid.create!(name: 'test-grid') }

  let(:stack) {
    Stacks::Create.run(
      grid: grid,
      name: 'stack',
      stack: 'foo/bar',
      version: '0.1.0',
      registry: 'file://',
      source: '...',
      labels: ['foo=bar'],
      services: [{name: 'redis', image: 'redis:2.8', stateful: true }]
    ).result
  }

  describe '#run' do
    it 'updates labels' do
      subject = described_class.new(
        stack_instance: stack,
        name: 'stack',
        labels: ['foo=bar', 'x=y']
      )

      outcome = subject.run()
      expect(outcome.success?).to be_truthy
      expect(outcome.result.labels).to eq(['foo=bar', 'x=y'])
    end

    it 'rejects nil labels' do
      subject = described_class.new(
        stack_instance: stack,
        name: 'stack',
        labels: ['foo=bar', 'x=y', nil]
      )

      outcome = subject.run()
      expect(outcome.success?).to be_falsey
      expect(outcome.result).to be_nil
    end

    it 'rejects empty labels' do
      subject = described_class.new(
        stack_instance: stack,
        name: 'stack',
        labels: ['foo=bar', 'x=y', '']
      )

      outcome = subject.run()
      expect(outcome.success?).to be_falsey
      expect(outcome.result).to be_nil
    end

    it 'rejects unknown stack' do
      subject = described_class.new(
        stack_instance: { name: Stack::NULL_STACK },
        name: 'stack',
        labels: ['foo=bar', 'x=y']
      )

      outcome = subject.run()
      expect(outcome.success?).to be_falsey
      expect(outcome.result).to be_nil
    end

    it 'rejects invalid labels' do
      subject = described_class.new(
        stack_instance: stack,
        name: 'stack',
        labels: ['foo', 'bar']
      )

      outcome = subject.run()
      expect(outcome.success?).to be_falsey
      expect(outcome.result).to be_nil
    end
  end
end
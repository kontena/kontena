
describe Kontena::ServicePods::Migrator do

  let(:container) do
    double(:container, name_for_humans: 'foo')
  end
  let(:subject) { described_class.new(container) }

  describe '#migrate' do
    it 'migrates container' do
      allow(container).to receive(:autostart?).and_return(true)
      expect(container).to receive(:update)
      subject.migrate
    end
  end

  describe '.legacy_container?' do
    it 'returns true if container has restart policies' do
      allow(container).to receive(:autostart?).and_return(true)
      expect(described_class.legacy_container?(container)).to be_truthy
    end

    it 'returns false if container is not legacy' do
      allow(container).to receive(:autostart?).and_return(false)
      expect(described_class.legacy_container?(container)).to be_falsey
    end
  end
end
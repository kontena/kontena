
describe Kontena::ServicePods::Migrator do

  let(:container) do
    double(:container, name_for_humans: 'foo')
  end
  let(:subject) { described_class.new(container) }

  describe '#migrate' do
    it 'migrates container' do
      allow(container).to receive(:autostart?).and_return(true)
      expect(container).to receive(:update)
      expect(container).to receive(:reload)
      subject.migrate
    end
  end
end

describe Kontena::ServicePods::Migrator do

  describe '.migrate_container' do
    it 'migrates container' do
      container = double(:container, host_config: {
        'RestartPolicy' => {
          'Name' => 'unless-stopped'
        }
      })
      expect(container).to receive(:update)
      described_class.migrate_container(container)
    end
  end

  describe '.legacy_container?' do
    it 'returns true if container has restart policies' do
      container = double(:container, host_config: {
        'RestartPolicy' => {
          'Name' => 'unless-stopped'
        }
      })

      expect(described_class.legacy_container?(container)).to be_truthy
    end

    it 'returns false if container is not legacy' do
      container = double(:container, host_config: {
        'RestartPolicy' => {}
      })

      expect(described_class.legacy_container?(container)).to be_truthy
    end
  end
end
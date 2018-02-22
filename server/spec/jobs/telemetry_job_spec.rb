
describe TelemetryJob, celluloid: true do

  let(:grid) { Grid.create!(name: 'test-grid', overlay_cidr: '10.81.0.0/23') }

  describe '#stats_enabled?' do
    it 'returns true by default' do
      config = {'server.telemetry_enabled' => 'true'}
      allow(subject.wrapped_object).to receive(:config).and_return(config)
      expect(subject.stats_enabled?).to be_truthy
    end

    it 'returns false if disabled' do
      config = {'server.telemetry_enabled' => 'false'}
      allow(subject.wrapped_object).to receive(:config).and_return(config)
      expect(subject.stats_enabled?).to be_falsey
    end
  end

  describe '#payload' do
    before(:each) do
      grid = Grid.create(name: 'test')
      grid.host_nodes.create(name: 'a', node_id: 'a')
    end

    it 'returns correct id' do
      config = {'server.uuid' => 'daa'}
      allow(subject.wrapped_object).to receive(:config).and_return(config)
      payload = subject.payload
      expect(payload).to include(:id => 'daa')
    end
  end
end

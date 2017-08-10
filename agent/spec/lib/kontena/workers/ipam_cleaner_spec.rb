describe Kontena::Workers::IpamCleaner, :celluloid => true do
  let(:actor) { described_class.new(start: false) }
  subject { actor.wrapped_object }
  let(:subject_async) { instance_double(described_class) }

  let(:ipam_plugin_launcher) { instance_double(Kontena::Launchers::IpamPlugin) }
  let(:ipam_info) { double() }
  let(:ipam_client) { instance_double(Kontena::NetworkAdapters::IpamClient) }

  before do
    allow(Celluloid::Actor).to receive(:[]).with(:ipam_plugin_launcher).and_return(ipam_plugin_launcher)
    allow(subject).to receive(:async).and_return(subject_async)

    allow(subject).to receive(:ipam_client).and_return(ipam_client)
  end

  describe '#initialize' do
    it 'calls #start by default' do
      expect_any_instance_of(described_class).to receive(:start)
      described_class.new()
    end
  end

  describe '#start' do
    it 'observes and calls run' do
      expect(subject).to receive(:observe).with(ipam_plugin_launcher) do |&block|
        expect(subject_async).to receive(:run)

        block.call(ipam_info)
      end

      actor.start
    end
  end

  describe '#run' do
    before do
      allow(subject).to receive(:every) do |&block|
        block.call
      end
    end

    it 'runs cleanup every' do
      expect(subject).to receive(:cleanup_ipam)

      subject.run
    end
  end

  describe '#cleanup_ipam' do
    it do
      expect(ipam_client).to receive(:cleanup_index).and_return(1)
      expect(subject).to receive(:sleep)
      expect(subject).to receive(:collect_local_addresses).and_return(['10.81.128.6/16'])
      expect(ipam_client).to receive(:cleanup_network).with('kontena', ['10.81.128.6/16'], 1)

      subject.cleanup_ipam
    end
  end

  describe '#collect_local_addresses' do
    let(:container1) { double(:container1, overlay_ip: '10.81.128.1/16')}
    let(:container2) { double(:container2, overlay_ip: '10.81.128.2/16')}
    let(:container3) { double(:container2, overlay_ip: nil )}

    before do
      allow(Docker::Container).to receive(:all).with(all: true).and_return [container1, container2, container3]
    end

    it do
      expect(subject.collect_local_addresses).to eq ['10.81.128.1/16', '10.81.128.2/16']
    end
  end
end

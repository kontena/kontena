require_relative '../../../spec_helper'

describe Kontena::Workers::ContainerNetworkMigratorWorker do

  let(:container) { spy(:container) }
  let(:network_adapter) { spy(:network_adapter) }
  let(:subject) { described_class.new(false) }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }


  describe '#should_migrate' do
    it 'returns true when container has overlay and no kontena network' do
      container = double(service_container?: true, labels: { 'io.kontena.container.overlay_cidr' => '10.81.0.100/16'})
      expect(container).to receive(:has_network?).with('kontena').and_return(false)
      expect(subject.should_migrate?(container)).to be_truthy
    end

    it 'returns false when container has overlay and kontena network' do
      container = double(service_container?: true, labels: { 'io.kontena.container.overlay_cidr' => '10.81.0.100/16'})
      expect(container).to receive(:has_network?).with('kontena').and_return(true)
      expect(subject.should_migrate?(container)).to be_falsey
    end

    it 'returns false when container has no overlay' do
      container = double(service_container?: true, labels: { })
      expect(subject.should_migrate?(container)).to be_falsey
    end
  end

  describe '#migrate_weavewait' do
    it 'migrates weavewait binary to no-op' do
      # TODO Why do we need this mock
      allow(Celluloid::Actor).to receive(:[]).with(:notifications_fanout).and_return(spy())
      allow(Celluloid::Actor).to receive(:[]).with(:network_adapter).and_return(network_adapter)
      expect(Docker::Container).to receive(:create).and_return(container)
      expect(container).to receive(:start)
      expect(container).to receive(:delete)
      subject.wrapped_object.migrate_weavewait
    end

    it 'retries weavewait migration binary to no-op' do
      # TODO Why do we need this mock
      allow(Celluloid::Actor).to receive(:[]).with(:notifications_fanout).and_return(spy())
      allow(Celluloid::Actor).to receive(:[]).with(:network_adapter).and_return(network_adapter)
      expect(Docker::Container).to receive(:create).and_return(container)
      expect(container).to receive(:start).exactly(10).times.and_raise(StandardError)
      allow(subject.wrapped_object).to receive(:sleep)
      expect(container).to receive(:delete)
      subject.wrapped_object.migrate_weavewait
    end

  end

  describe '#migrate_network' do
    it 'migrates network' do
      network = double
      expect(Docker::Network).to receive(:get).with('kontena').and_return(network)
      allow(Celluloid::Actor).to receive(:[]).with(:network_adapter).and_return(network_adapter)
      allow(Celluloid::Actor).to receive(:[]).with(:notifications_fanout).and_return(spy())
      expect(network_adapter).to receive(:detach_network)
      expect(network).to receive(:connect)
      subject.migrate_network(container)
    end

    it 'does not migrate when kontena network not found' do
      network = double
      expect(Docker::Network).to receive(:get).with('kontena').and_return(nil)
      expect(network_adapter).not_to receive(:detach_network)
      expect(network).not_to receive(:connect)
      subject.migrate_network(container)
    end

    it 'does not migrate when kontena network not found' do
      network = double
      expect(Docker::Network).to receive(:get).with('kontena').and_raise(Docker::Error::NotFoundError)
      expect(network_adapter).not_to receive(:detach_network)
      expect(network).not_to receive(:connect)
      subject.migrate_network(container)
    end
  end

end

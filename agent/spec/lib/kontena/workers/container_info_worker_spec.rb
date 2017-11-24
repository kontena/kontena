
describe Kontena::Workers::ContainerInfoWorker, celluloid: true do
  include RpcClientMocks

  let(:node_id) { 'U3CZ:W2PA:2BRD:66YG:W5NJ:CI2R:OQSK:FYZS:NMQQ:DIV5:TE6K:R6GS' }
  let(:subject) { described_class.new(node_id, false) }

  before(:each) do
    mock_rpc_client
  end

  describe '#start' do
    it 'calls #publish_all_containers if rpc client is connected' do
      allow(rpc_client).to receive(:connected?).and_return(true)
      expect(subject.wrapped_object).to receive(:publish_all_containers)
      subject.start
    end

    it 'does not call #publish_all_containers if rpc client is not connected' do
      allow(rpc_client).to receive(:connected?).and_return(false)
      expect(subject.wrapped_object).not_to receive(:publish_all_containers)
      subject.start
    end
  end

  describe '#on_websocket_connected' do
    let(:coroner) do
      double(:coroner)
    end

    before(:each) do
      allow(coroner).to receive(:start)
      allow(subject.wrapped_object).to receive(:publish_all_containers)
    end

    it 'calls #publish_all_containers' do
      expect(subject.wrapped_object).to receive(:publish_all_containers)
      subject.on_websocket_connected('websocket:connected', nil)
    end
  end

  describe '#on_container_event' do
    it 'does nothing if status == destroy' do
      event = double(:event, status: 'destroy')
      expect(Docker::Container).not_to receive(:get)
      subject.on_container_event('topic', event)
    end

    it 'fetches container info' do
      event = double(:event, status: 'start', id: 'foo')
      container = spy(:container, :config => {'Image' => 'foo/bar:latest'})
      expect(Docker::Container).to receive(:get).once.and_return(container)
      expect(subject.wrapped_object).to receive(:publish_info).with(container)
      subject.on_container_event('topic', event)
    end

    it 'publishes destroy event if container is not found' do
      event = double(:event, status: 'start', id: 'foo')
      expect(Docker::Container).to receive(:get).once.and_raise(Docker::Error::NotFoundError)
      expect(subject.wrapped_object).to receive(:publish_destroy_event).with(event)
      subject.on_container_event('topic', event)
    end

    it 'logs error on unknown exception' do
      event = double(:event, status: 'start', id: 'foo')
      expect(Docker::Container).to receive(:get).once.and_raise(StandardError)
      expect(subject.wrapped_object).to receive(:error).twice
      subject.on_container_event('topic', event)
    end
  end

  describe '#publish_info' do
    it 'publishes event to queue' do
      expect(rpc_client).to receive(:request).once
      subject.publish_info(spy(:container, json: {'Config' => {}}))
    end

    it 'publishes valid message' do
      container = double(:container, json: {'Config' => {}})
      expect(rpc_client).to receive(:request).once.with(
        '/containers/save', [hash_including(node: node_id, container: Hash)]
      )
      subject.publish_info(container)
    end
  end
end

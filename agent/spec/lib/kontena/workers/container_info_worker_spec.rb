
describe Kontena::Workers::ContainerInfoWorker do
  include RpcClientMocks

  let(:subject) { described_class.new(false) }

  before(:each) do
    Celluloid.boot
    allow(Docker).to receive(:info).and_return({
      'Name' => 'node-1',
      'Labels' => nil,
      'ID' => 'U3CZ:W2PA:2BRD:66YG:W5NJ:CI2R:OQSK:FYZS:NMQQ:DIV5:TE6K:R6GS'
    })
    mock_rpc_client
  end

  after(:each) do
    Celluloid.shutdown
  end

  describe '#start' do
    it 'calls #publish_all_containers' do
      allow(subject.wrapped_object).to receive(:publish_all_containers)
      subject.start
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
      expect(subject.wrapped_object.logger).to receive(:error).twice
      subject.on_container_event('topic', event)
    end

    it 'notifies coroner if container is dead' do
      event = double(:event, status: 'die', id: 'foo')
      container = double(:container, :json => {'Image' => 'foo/bar:latest'}, :suspiciously_dead? => true)
      allow(Docker::Container).to receive(:get).once.and_return(container)
      expect(subject.wrapped_object).to receive(:notify_coroner).with(container)
      subject.on_container_event('topic', event)
    end

    it 'does not notify coroner if container is alive' do
      event = double(:event, status: 'start', id: 'foo')
      container = double(:container, :json => {'Image' => 'foo/bar:latest'}, :suspiciously_dead? => false)
      allow(Docker::Container).to receive(:get).once.and_return(container)
      expect(subject.wrapped_object).not_to receive(:notify_coroner).with(container)
      subject.on_container_event('topic', event)
    end
  end

  describe '#publish_info' do
    it 'publishes event to queue' do
      expect(rpc_client).to receive(:notification).once
      subject.publish_info(spy(:container, json: {'Config' => {}}))
    end

    it 'publishes valid message' do
      container = double(:container, json: {'Config' => {}})
      expect(rpc_client).to receive(:notification).once.with(
        '/containers/save', [hash_including(node: 'host_id')]
      )
      allow(subject.wrapped_object).to receive(:node_info).and_return({'ID' => 'host_id'})
      subject.publish_info(container)
    end
  end

  describe '#notify_coroner' do
    let(:container) do
      double(:container, id: 'dead-id', name: '/dead')
    end

    it 'creates a coroner actor' do
      coroner = subject.notify_coroner(container)
      expect(coroner).to be_an_instance_of(Kontena::Actors::ContainerCoroner)
    end
  end
end

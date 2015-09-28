require_relative '../../spec_helper'

describe Kontena::LoadBalancerRegistrator do

  before(:each) do
    allow_any_instance_of(described_class).to receive(:gateway).and_return('172.72.42.1')
  end

  let(:event) { spy(:event, id: 'foobar', status: 'start') }
  let(:container) { spy(:container, id: '12345', info: {'Name' => 'test'}) }

  describe '#initialize' do
    it 'starts to listen container events' do
      expect(subject).to receive(:on_container_event).once.with(event)
      Kontena::Pubsub.publish('container:event', event)
      sleep 0.05
    end
  end

  describe '#on_container_event' do
    it 'calls #register_container on start event' do
      allow(Docker::Container).to receive(:get).with(event.id).and_return(container)
      expect(subject).to receive(:register_container).once.with(container)
      subject.on_container_event(event)
    end

    it 'calls #unregister_container on die event' do
      allow(event).to receive(:status).and_return('die')
      allow(Docker::Container).to receive(:get).with(event.id).and_return(container)
      expect(subject).to receive(:unregister_container).once.with(event.id)
      subject.on_container_event(event)
    end
  end

  describe '#load_balanced?' do
    it 'returns false if container is notbalanced' do
      expect(subject.load_balanced?(container)).to eq(true)
    end
    it 'returns true if container is balanced' do
      allow(container).to receive(:info).and_return({
        'Config' => {
          'Labels' => {
            'io.kontena.load_balancer.name' => 'lb1'
          }
        }
      })
      expect(subject.load_balanced?(container)).to eq(true)
    end
  end

  describe '#etcd_running?' do
    it 'returns false if etcd does not exist' do
      expect(Docker::Container).to receive(:get).with('kontena-etcd').and_raise(Docker::Error::NotFoundError.new('foo'))
      expect(subject.etcd_running?).to eq(false)
    end

    it 'returns false if etcd is not running' do
      expect(Docker::Container).to receive(:get).
        with('kontena-etcd').and_return(spy(:etcd, info: {'State' => {}}))
      expect(subject.etcd_running?).to eq(false)
    end

    it 'returns true if etcd is running' do
      expect(Docker::Container).to receive(:get).
        with('kontena-etcd').and_return(spy(:etcd, info: {
          'State' => {'Running' => true}
        })
      )
      expect(subject.etcd_running?).to eq(true)
    end
  end

  describe '#register_container' do
    let(:container) {
      spy(:container, id: '12345', json: {
        'Name' => 'test',
        'Config' => {
          'Labels' => {}
        }
      })
    }
    let(:http_container) {
      spy(:container, id: '12345', json: {
        'Name' => 'test',
        'Config' => {
          'Labels' => {
            'io.kontena.load_balancer.name' => 'lb1',
            'io.kontena.service.name' => 'web',
            'io.kontena.container.name' => 'web-2',
            'io.kontena.container.overlay_cidr' => '10.81.3.24/19',
            'io.kontena.load_balancer.internal_port' => '8080',
            'io.kontena.load_balancer.mode' => 'http'
          }
        }
      })
    }

    it 'registers container ip:port to etcd' do
      expect(subject.etcd).to receive(:set).with(anything, {value: '10.81.3.24:8080'})
      subject.register_container(http_container)
    end

    it 'registers container info to cache' do
      allow(subject.etcd).to receive(:set)
      expect(subject.cache).to receive(:[]=).with(
        http_container.id, hash_including(lb: 'lb1', service: 'web', container: 'web-2')
      )
      subject.register_container(http_container)
    end

    it 'does nothing if container does not have lb info' do
      expect(subject.etcd).not_to receive(:set)
      subject.register_container(container)
    end
  end

  describe '#unregister_container' do
    it 'unregisters container if id exists in cache' do
      allow(subject.cache).to receive(:[]).with(event.id).and_return(true)
      allow(subject.cache).to receive(:delete).with(event.id).and_return({
        lb: 'lb1', service: 'web', container: 'web-2'
      })

      expect(subject.etcd).to receive(:delete)
      subject.unregister_container(event.id)
    end

    it 'does nothing if id is not in cache' do
      expect(subject.etcd).not_to receive(:delete)
      subject.unregister_container(event.id)
    end
  end
end

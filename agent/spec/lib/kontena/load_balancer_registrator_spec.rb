require_relative '../../spec_helper'

describe Kontena::LoadBalancerRegistrator do

  before(:each) do
    allow_any_instance_of(described_class).to receive(:gateway).and_return('172.72.42.1')
  end

  let(:event) { spy(:event, id: 'foobar', status: 'start') }
  let(:container) { spy(:container, id: '12345', info: {'Name' => 'test'}) }

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
end

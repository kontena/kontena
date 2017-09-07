
describe Kontena::NetworkAdapters::DnsManager do
  let(:event) { spy(:event, id: 'foobar', status: 'start') }
  let(:container) { spy(:container, id: '12345', info: {'Name' => 'test'}) }
  let(:network_adapter) { instance_double(Kontena::NetworkAdapters::Weave) }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  before(:each) do
    allow(Celluloid::Actor).to receive(:[]).and_call_original
    allow(Celluloid::Actor).to receive(:[]).with(:network_adapter).and_return(network_adapter)
    allow(subject.wrapped_object).to receive(:wait_weave_running?).and_return(true)
  end

  describe '#on_weave_start' do
    it 'calls start' do
      expect(subject.wrapped_object).to receive(:start)
      Celluloid::Notifications.publish('network_adapter:start', nil)
      subject.started? # sync ping to wait for async notification task to run
    end
  end
  describe '#on_weave_restart' do
    it 'calls start' do
      expect(subject.wrapped_object).to receive(:start)
      Celluloid::Notifications.publish('network_adapter:restart', nil)
      subject.started? # sync ping to wait for async notification task to run
    end
  end

  describe '#on_container_event' do
    before(:each) do
      allow(network_adapter).to receive(:running?).and_return(true)
      allow(subject.wrapped_object).to receive(:started?).and_return(true)
    end

    it 'does not do anything if not started' do
      allow(subject.wrapped_object).to receive(:started?).and_return(false)
      expect(Docker::Container).not_to receive(:get)
      subject.on_container_event('topic', event)
    end
  end

  describe '#register_container_dns' do
    before(:each) do
      allow(container).to receive(:overlay_ip).and_return('10.81.1.1')
    end

    it 'registers all dns names for default stack' do
      allow(container).to receive(:labels).and_return({
        'io.kontena.stack.name' => 'null',
        'io.kontena.grid.name' => 'foo',
        'io.kontena.service.name' => 'redis',
        'io.kontena.service.instance_number' => 2,
        'io.kontena.container.name' => 'null-redis-2',
        'io.kontena.container.type' => 'infra',
        'io.kontena.container.hostname' => 'redis-2',
        'io.kontena.container.domainname' => 'foo.kontena.local'
      })
      names = []
      expect(subject.wrapped_object).to receive(:add_dns).exactly(4).times { |id, ip, name|
        names << name
      }
      subject.register_container_dns(container)
      expect(names).to include('redis-2.kontena.local')
      expect(names).to include('redis-2.foo.kontena.local')
      expect(names).to include('redis.kontena.local')
      expect(names).to include('redis.foo.kontena.local')
    end

    it 'registers all dns names for non-default stack' do
      allow(container).to receive(:default_stack?).and_return(false)
      allow(container).to receive(:labels).and_return({
        'io.kontena.stack.name' => 'custom',
        'io.kontena.grid.name' => 'foo',
        'io.kontena.service.name' => 'redis',
        'io.kontena.service.instance_number' => 2,
        'io.kontena.container.name' => 'redis-2',
        'io.kontena.container.type' => 'infra',
        'io.kontena.container.hostname' => 'redis-2',
        'io.kontena.container.domainname' => 'custom.foo.kontena.local'
      })
      names = []
      expect(subject.wrapped_object).to receive(:add_dns).exactly(2).times { |id, ip, name|
        names << name
      }
      subject.register_container_dns(container)
      expect(names).to include('redis-2.custom.foo.kontena.local')
      expect(names).to include('redis.custom.foo.kontena.local')
    end

    it 'registers all dns names for non-default exposed stack' do
      allow(container).to receive(:default_stack?).and_return(false)
      allow(container).to receive(:labels).and_return({
        'io.kontena.stack.name' => 'custom',
        'io.kontena.grid.name' => 'foo',
        'io.kontena.service.exposed' => '1',
        'io.kontena.service.name' => 'redis',
        'io.kontena.service.instance_number' => 2,
        'io.kontena.container.name' => 'redis-2',
        'io.kontena.container.type' => 'infra',
        'io.kontena.container.hostname' => 'redis-2',
        'io.kontena.container.domainname' => 'custom.foo.kontena.local'
      })
      names = []
      expect(subject.wrapped_object).to receive(:add_dns).exactly(4).times { |id, ip, name|
        names << name
      }
      subject.register_container_dns(container)
      expect(names).to include('redis-2.custom.foo.kontena.local')
      expect(names).to include('redis.custom.foo.kontena.local')
      expect(names).to include('custom.foo.kontena.local')
      expect(names).to include('custom-2.foo.kontena.local')
    end
  end
end

describe Kontena::Workers::WeaveWorker do

  let(:event) { spy(:event, id: 'foobar', status: 'start') }
  let(:container) { spy(:container, id: '12345', info: {'Name' => 'test'}) }
  let(:network_adapter) { instance_double(Kontena::NetworkAdapters::Weave) }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  before(:each) do
    allow(Celluloid::Actor).to receive(:[]).and_call_original
    allow(Celluloid::Actor).to receive(:[]).with(:network_adapter).and_return(network_adapter)

    # initialize without calling start()
    allow(network_adapter).to receive(:already_started?).and_return(false).once
    subject
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

    it 'calls #weave_attach on start event' do
      allow(Docker::Container).to receive(:get).with(event.id).and_return(container)
      expect(subject.wrapped_object).to receive(:start_container).once.with(container)
      subject.on_container_event('topic', event)
    end

    it 'calls #weave_detach on destroy event' do
      allow(event).to receive(:status).and_return('destroy')
      expect(subject.wrapped_object).to receive(:on_container_destroy).once.with(event)
      subject.on_container_event('topic', event)
    end

    it 'calls #start on weave restart event' do
      event = spy(:event, id: 'foobar', status: 'restart', from: 'weaveworks/weave:1.4.5')
      expect(subject.wrapped_object).to receive(:router_image?).with('weaveworks/weave:1.4.5').and_return(true)
      expect(subject.wrapped_object).to receive(:start).once
      subject.on_container_event('topic', event)
    end

    it 'does not do anything if not started' do
      allow(subject.wrapped_object).to receive(:started?).and_return(false)
      expect(Docker::Container).not_to receive(:get)
      expect(network_adapter).not_to receive(:router_image?)
      subject.on_container_event('topic', event)
    end
  end

  describe '#start_container' do
    before(:each) do
      allow(network_adapter).to receive(:running?).and_return(true)
    end

    it 'attaches overlay if container has overlay_cidr' do
      allow(container).to receive(:overlay_cidr).and_return('10.81.1.1/16')
      allow(subject.wrapped_object).to receive(:register_container_dns)
      expect(subject.wrapped_object).to receive(:attach_overlay).with(container)
      subject.start_container(container)
    end

    it 'does not attach overlay if container is not service container' do
      allow(container).to receive(:service_container?).and_return(false)
      allow(container).to receive(:overlay_cidr).and_return('10.81.1.1/16')
      expect(subject.wrapped_object).not_to receive(:register_container_dns)
      expect(subject.wrapped_object).to receive(:attach_overlay).with(container)
      subject.start_container(container)
    end

    it 'does not attach overlay if container does not have overlay_cidr' do
      allow(container).to receive(:overlay_cidr).and_return(nil)
      allow(subject.wrapped_object).to receive(:register_container_dns)
      expect(subject.wrapped_object).not_to receive(:attach_overlay).with(container)
      subject.start_container(container)
    end

    it 'registers dns if container has overlay_cidr' do
      allow(container).to receive(:overlay_cidr).and_return('10.81.1.1/16')
      allow(subject.wrapped_object).to receive(:attach_overlay)
      expect(subject.wrapped_object).to receive(:register_container_dns).with(container)
      subject.start_container(container)
    end

    it 'does not register dns if container does not have overlay_cidr' do
      allow(container).to receive(:overlay_cidr).and_return(nil)
      allow(subject.wrapped_object).to receive(:attach_overlay)
      expect(subject.wrapped_object).not_to receive(:register_container_dns)
      subject.start_container(container)
    end
  end

  describe '#attach_overlay' do
    before do
      allow(network_adapter).to receive(:get_containers).and_return(migrate_containers)
      allow(Docker::Container).to receive(:all).and_return([])

      subject.start
    end

    context "For a 1.0 container that is not yet running" do
      let(:container) do
        double(Docker::Container,
          id: '123456789ABCDEF',
          name: 'test',
          overlay_cidr: '10.81.128.1/16',
          overlay_suffix: '16',
          overlay_network: 'kontena',
        )
      end

      let :migrate_containers do
        { }
      end

      it 'calls network_adapter.attach_container' do
        expect(network_adapter).to receive(:attach_container).with('123456789ABCDEF', '10.81.128.1/16')

        subject.attach_overlay(container)
      end
    end

    context "For a 0.16 container that is still running" do
      let(:container) do
        double(Docker::Container,
          id: '123456789ABCDEF',
          name: 'test',
          overlay_cidr: '10.81.1.1/19',
          overlay_ip: '10.81.1.1',
          overlay_suffix: '19',
          overlay_network: nil,
        )
      end

      let :migrate_containers do
        { '123456789ABC' => ['10.81.1.1/19']}
      end

      it 'calls network_adapter.migrate_container' do
        expect(network_adapter).to receive(:migrate_container).with('123456789ABCDEF', '10.81.1.1/16', ['10.81.1.1/19'])

        subject.attach_overlay(container)
      end
    end

    context "For a 0.16 container that has already been migrated" do
      let(:container) do
        double(Docker::Container,
          id: '123456789ABCDEF',
          name: 'test',
          overlay_cidr: '10.81.1.1/19',
          overlay_ip: '10.81.1.1',
          overlay_suffix: '19',
          overlay_network: nil,
        )
      end

      let :migrate_containers do
        #{ '123456789ABC' => ['10.81.1.1/16']}
        { }
      end

      it 'calls network_adapter.attach_container' do
        expect(network_adapter).to receive(:attach_container).with('123456789ABCDEF', '10.81.1.1/16')

        subject.attach_overlay(container)
      end
    end
  end

  describe '#register_container_dns' do
    before(:each) do
      allow(container).to receive(:overlay_ip).and_return('10.81.1.1')
    end

    it 'registers all dns names for legacy container' do
      allow(container).to receive(:config).and_return({
        'Hostname' => 'redis-2.kontena.local'
      })
      allow(container).to receive(:labels).and_return({
        'io.kontena.grid.name' => 'foo',
        'io.kontena.service.name' => 'redis',
        'io.kontena.service.instance_number' => 2,
        'io.kontena.container.name' => 'redis-2'
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

    it 'registers all dns names for default stack' do
      allow(container).to receive(:config).and_return({
        'Domainname' => 'foo.kontena.local',
        'Hostname' => 'redis-2'
      })
      allow(container).to receive(:labels).and_return({
        'io.kontena.stack.name' => 'null',
        'io.kontena.grid.name' => 'foo',
        'io.kontena.service.name' => 'redis',
        'io.kontena.service.instance_number' => 2,
        'io.kontena.container.name' => 'null-redis-2'
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
      allow(container).to receive(:config).and_return({
        'Domainname' => 'custom.foo.kontena.local',
        'Hostname' => 'redis-2'
      })
      allow(container).to receive(:labels).and_return({
        'io.kontena.stack.name' => 'custom',
        'io.kontena.grid.name' => 'foo',
        'io.kontena.service.name' => 'redis',
        'io.kontena.service.instance_number' => 2,
        'io.kontena.container.name' => 'redis-2'
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
      allow(container).to receive(:config).and_return({
        'Domainname' => 'custom.foo.kontena.local',
        'Hostname' => 'redis-2'
      })
      allow(container).to receive(:labels).and_return({
        'io.kontena.stack.name' => 'custom',
        'io.kontena.grid.name' => 'foo',
        'io.kontena.service.exposed' => '1',
        'io.kontena.service.name' => 'redis',
        'io.kontena.service.instance_number' => 2,
        'io.kontena.container.name' => 'redis-2'
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

    it 'registers all dns names for legacy stack' do
      allow(container).to receive(:config).and_return({
        'Domainname' => '',
        'Hostname' => 'redis-2'
      })
      allow(container).to receive(:labels).and_return({
        'io.kontena.grid.name' => 'foo',
        'io.kontena.service.name' => 'redis',
        'io.kontena.service.instance_number' => 2,
        'io.kontena.container.name' => 'redis-2'
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
  end
end

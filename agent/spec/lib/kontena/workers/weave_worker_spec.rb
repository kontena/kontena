describe Kontena::Workers::WeaveWorker, :celluloid => true do
  let(:actor) { described_class.new(start: false) }
  subject { actor.wrapped_object }
  let(:subject_async) { instance_double(described_class) }

  let(:weave_executor) { instance_double(Kontena::NetworkAdapters::WeaveExecutor) }
  let(:weave_launcher) { instance_double(Kontena::Launchers::Weave) }
  let(:weave_info) { {} }
  let(:etcd_launcher) { instance_double(Kontena::Launchers::Etcd) }
  let(:etcd_info) { {container_id: 'abcdef', overlay_ip: '10.81.0.2', dns_name: 'etcd.kontena.local'} }

  let(:weave_client) { instance_double(Kontena::NetworkAdapters::WeaveClient) }

  before(:each) do
    allow(subject).to receive(:async).and_return(subject_async)

    allow(Celluloid::Actor).to receive(:[]).with(:weave_launcher).and_return(weave_launcher)
    allow(Celluloid::Actor).to receive(:[]).with(:etcd_launcher).and_return(etcd_launcher)

    allow(subject).to receive(:weave_executor).and_return(weave_executor)
    allow(subject).to receive(:weave_client).and_return(weave_client)
  end

  describe '#initialize' do
    it 'calls #start by default' do
      expect_any_instance_of(described_class).to receive(:start)
      described_class.new()
    end
  end

  describe '#start' do
    it 'observes and subscribes container:event' do
      expect(subject).to receive(:observe).with(weave_launcher, etcd_launcher) do |&block|
        expect(subject).to receive(:ensure_containers_attached)
        expect(subject).to receive(:ensure_etcd_dns).with(etcd_info)

        block.call(weave_info, etcd_info)
      end
      expect(subject).to receive(:subscribe).with('container:event', :on_container_event)

      actor.start
    end
  end

  describe '#ensure_etcd_dns' do
    it 'adds dns using the weave client' do
      expect(weave_client).to receive(:add_dns).with('abcdef', '10.81.0.2', 'etcd.kontena.local')

      subject.ensure_etcd_dns(etcd_info)
    end
  end

  describe '#ensure_containers_attached' do
    let(:container1) { double(:container1) }
    let(:container2) { double(:container2) }

    it 'inspects and starts containers' do
      expect(subject).to receive(:inspect_containers).and_return({})
      expect(Docker::Container).to receive(:all).with(all: false).and_return [
        container1,
        container2,
      ]
      expect(subject).to receive(:start_container).with(container1)
      expect(subject).to receive(:start_container).with(container2)

      expect{
        subject.ensure_containers_attached
      }.to change{subject.containers_attached?}.from(false).to(true)
    end
  end

  describe '#on_container_event' do
    let(:containers_attached?) { true }

    let(:container) { double(:container, id: '12345',
      name: 'test',
    ) }

    let(:start_event) { double(:event, id: '12345', status: 'start') }
    let(:restart_event) { double(:event, id: '12345', from: 'test/foo:test', status: 'restart') }
    let(:weave_restart_event) { double(:event, id: '12345', from: 'weaveworks/weave:test', status: 'restart') }
    let(:host_destroy_event) { double(:event, id: '12345', status: 'destroy', Actor: double(attributes: {})) }
    let(:destroy_event) { double(:event, id: '12345', status: 'destroy', Actor: double(attributes: {
      'io.kontena.container.overlay_network' => 'kontena',
      'io.kontena.container.overlay_cidr' => '10.81.128.6/16',
    }) ) }

    before do
      allow(subject).to receive(:containers_attached?).and_return(containers_attached?)
    end

    context 'without containers attached' do
      let(:containers_attached?) { false }

      it 'does nothing' do
        expect(subject).to_not receive(:on_container_destroy)

        actor.on_container_event('container:event', destroy_event)
      end
    end

    it 'ignores start events for missing containers' do
      allow(Docker::Container).to receive(:get).with('12345').and_raise(Docker::Error::NotFoundError)

      expect(subject).to_not receive(:start_container)

      subject.on_container_event('container:event', start_event)
    end

    it 'calls #start_container on start event' do
      allow(Docker::Container).to receive(:get).with('12345').and_return(container)

      expect(subject).to receive(:start_container).once.with(container)

      subject.on_container_event('container:event', start_event)
    end

    it 'does nothing on non-overlay destroy event' do
      expect(subject_async).to_not receive(:on_container_destroy)

      subject.on_container_event('container:event', host_destroy_event)
    end

    it 'releases container address on destroy event' do
      expect(subject).to receive(:on_container_destroy).with(destroy_event).and_call_original
      expect(subject_async).to receive(:release_container_address).with('12345', 'kontena', '10.81.128.6/16')

      subject.on_container_event('container:event', destroy_event)
    end

    it 'does nothing on service restart event' do
      expect(subject).to_not receive(:ensure_containers_attached)

      subject.on_container_event('container:event', restart_event)
    end

    it 'calls #ensure_containers_attached on weave restart event' do
      expect(subject).to receive(:ensure_containers_attached)

      subject.on_container_event('container:event', weave_restart_event)
    end
  end

  describe '#inspect_containers' do
    let(:weave_ps) { [
      ['weave:expose', 'a2:79:76:d0:ba:bd', '10.81.0.4/16'],
      ['f6dec24f48ff', 'f2:db:8a:e7:38:a3', '10.81.128.54/16'],
      ['4a86545d0f4c', '32:c1:bb:1d:d3:2b', '10.81.128.110/16'],
      ['d96291d6c294', '9a:45:e4:41:52:c5', '10.81.128.91/16'],
      ['487eac46f4aa', '32:b4:91:00:ed:79', '10.81.128.5/16'],
      ['2f44eb9c328f', '8a:ce:6f:e4:2a:98', '10.81.128.83/16'],
    ] }

    before do
      allow(weave_executor).to receive(:ps!) do |&block|
        weave_ps.each do |args|
          block.call(*args)
        end
      end
    end

    it 'returns hash of containers' do
      expect(subject.inspect_containers).to eq(
        'f6dec24f48ff' => ['10.81.128.54/16'],
        '4a86545d0f4c' => ['10.81.128.110/16'],
        'd96291d6c294' => ['10.81.128.91/16'],
        '487eac46f4aa' => ['10.81.128.5/16'],
        '2f44eb9c328f' => ['10.81.128.83/16'],
      )
    end
  end

  describe '#start_container' do
    context 'for a non-overlay container' do
      let(:container) { double(:container, id: '12345',
        name: 'test',
        overlay_cidr: nil,
      ) }

      it 'does not attach overlay or register dns' do
        expect(subject).not_to receive(:attach_overlay)
        expect(subject).not_to receive(:register_container_dns)

        subject.start_container(container)
      end
    end

    context 'for an overlay container' do
      let(:container) { double(:container, id: '12345',
        name: 'test',
        overlay_network: 'kontena',
        overlay_cidr: '10.81.128.6/16',
      ) }

      it 'attaches overlay and registers DNS' do
        expect(subject).to receive(:start_container_overlay).with(container)
        expect(subject).to receive(:register_container_dns).with(container)
        subject.start_container(container)
      end
    end
  end

  describe '#attach_overlay' do
    let(:migrate_containers) { { } }

    before do
      subject.instance_variable_set('@migrate_containers', migrate_containers)
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
        expect(subject).to receive(:attach_container).with('123456789ABCDEF', '10.81.128.1/16')

        subject.start_container_overlay(container)
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
        expect(subject).to receive(:migrate_container).with('123456789ABCDEF', '10.81.1.1/16', ['10.81.1.1/19'])

        subject.start_container_overlay(container)
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
        expect(subject).to receive(:attach_container).with('123456789ABCDEF', '10.81.1.1/16')

        subject.start_container_overlay(container)
      end
    end
  end

  describe '#register_container_dns' do
    let(:container) { double(:container, id: '12345',
      name: 'test',
      overlay_ip: '10.81.1.1',
      default_stack?: true,
    ) }

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
      expect(weave_client).to receive(:add_dns).exactly(4).times { |id, ip, name|
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
      expect(weave_client).to receive(:add_dns).exactly(4).times { |id, ip, name|
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
      expect(weave_client).to receive(:add_dns).exactly(2).times { |id, ip, name|
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
      expect(weave_client).to receive(:add_dns).exactly(4).times { |id, ip, name|
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
      expect(weave_client).to receive(:add_dns).exactly(4).times { |id, ip, name|
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

describe Kontena::Workers::ServicePodWorker, :celluloid => true do
  include RpcClientMocks

  let(:node) { Node.new('id' => 'aa') }
  let(:service_pod) do
    Kontena::Models::ServicePod.new(
      'id' => 'foo/2',
      'instance_number' => 2,
      'updated_at' => Time.now.to_s,
      'deploy_rev' => Time.now.to_s,
    )
  end
  let(:subject) { described_class.new(node, service_pod) }

  describe '#apply' do
    let(:container_id) { '8919f1a9fd05a0730a4b36549771e25895d71b9dd54c426bd6f5be969d39773c' }
    let(:overlay_ip) { '10.81.128.1' }
    let(:container_started_at) { Time.now }
    let(:container) {double(:container, id: container_id,
      name: 'foo-2',
      overlay_ip: overlay_ip,
      started_at: container_started_at,
    ) }
    let(:restarted_container) {double(:container, id: container_id,
      name: 'foo-2',
      overlay_ip: overlay_ip,
      started_at: container_started_at + 1.0,
    ) }

    it 'ensures the container, and syncs to master' do
      expect(subject.wrapped_object).to receive(:ensure_desired_state).and_return(container)
      expect(subject.wrapped_object).to receive(:sync_state_to_master).with(service_pod, container)

      subject.apply
    end

    it 'ensures the container, and syncs errors to master' do
      expect(subject.wrapped_object).to receive(:ensure_desired_state).and_raise(RuntimeError.new('test'))
      expect(subject.wrapped_object).to receive(:sync_state_to_master).with(service_pod, nil, RuntimeError)

      subject.apply
    end

    context 'with wait_for_port' do
      let(:service_pod) do
        Kontena::Models::ServicePod.new(
          'id' => 'foo/2',
          'instance_number' => 2,
          'updated_at' => Time.now.to_s,
          'deploy_rev' => Time.now.to_s,
          'desired_state' => 'running',
          'wait_for_port' => 1337,
        )
      end

      it 'syncs state after waiting for the port' do
        expect(subject.wrapped_object).to receive(:ensure_desired_state).and_return(container)
        expect(subject.wrapped_object).to receive(:port_open?).with(overlay_ip, 1337, timeout: 1.0).and_return(true)
        expect(subject.wrapped_object).to receive(:sync_state_to_master).with(service_pod, container)

        subject.apply
      end

      it 'aborts if the container crashes and restarts' do
        expect(subject.wrapped_object).to receive(:ensure_desired_state).once.and_return(container)
        expect(subject.wrapped_object).to receive(:port_open?).with(overlay_ip, 1337, timeout: 1.0).once do
          expect(subject.wrapped_object).to receive(:ensure_desired_state).once.and_return(restarted_container)
          expect(subject.wrapped_object).to receive(:wait_for_port)
          # XXX: in this case both the failing initial wait_for_port, and the restart will report state...
          expect(subject.wrapped_object).to receive(:sync_state_to_master).with(service_pod, restarted_container)

          subject.on_container_event('container:event', double(id: container_id, status: 'die'))

          false
        end
        allow(subject.wrapped_object).to receive(:sleep)
        allow(subject.wrapped_object).to receive(:port_open?).with(overlay_ip, 1337, timeout: 1.0).and_return(false)
        expect(subject.wrapped_object).to receive(:sync_state_to_master).with(service_pod, container, RuntimeError) do |pod, container, error|
          expect(error.message).to match /container restarted/
        end


        subject.apply
      end
    end

    describe 'when terminating a service pod' do
      it 'ensures the container, and terminates' do
        expect(subject.wrapped_object).to receive(:ensure_desired_state) do
          expect(service_pod).to be_terminated
          nil
        end
        expect(subject.wrapped_object).to receive(:terminate)
        expect(subject.wrapped_object).to_not receive(:sync_state_to_master)

        subject.destroy
      end
    end
  end

  describe '#ensure_desired_state' do
    before(:each) do
      allow(subject.wrapped_object).to receive(:migrate_container)
    end

    it 'calls ensure_running if container does not exist and service_pod desired_state is running' do
      container = double(:container, :running? => true, :restarting? => false, name: 'foo-2')
      expect(subject.wrapped_object).to receive(:get_container).and_return(nil)
      allow(service_pod).to receive(:running?).and_return(true)
      expect(subject.wrapped_object).to receive(:ensure_running)
      expect(subject.wrapped_object).to receive(:get_container).and_return(container)
      expect(subject.ensure_desired_state).to eq container
    end

    it 'calls ensure_running if container is not running and service_pod desired_state is running' do
      container = double(:container, :running? => false, :restarting? => false, name: 'foo-2')
      expect(subject.wrapped_object).to receive(:get_container).and_return(container)
      allow(subject.wrapped_object).to receive(:service_container_outdated?).and_return(false)
      allow(service_pod).to receive(:running?).and_return(true)
      expect(subject.wrapped_object).to receive(:ensure_started)
      expect(subject.wrapped_object).to receive(:get_container).and_return(container)
      expect(subject.ensure_desired_state).to eq container
    end

    it 'calls ensure_running if updated_at is newer than container' do
      container = double(:container,
        :running? => true, :restarting? => false,
        :info => { 'Created' => (Time.now - 30).to_s },
        :name => 'foo-2',
      )
      expect(subject.wrapped_object).to receive(:get_container).and_return(container)
      allow(service_pod).to receive(:running?).and_return(true)
      allow(service_pod).to receive(:service_rev).and_return(1)
      expect(subject.wrapped_object).to receive(:ensure_running)
      expect(subject.wrapped_object).to receive(:get_container).and_return(container)
      expect(subject.ensure_desired_state).to eq container
    end

    it 'calls ensure_stopped if container is running and service_pod desired_state is stopped' do
      container = double(:container, :running? => true, :restarting? => false, name: 'foo-2')
      expect(subject.wrapped_object).to receive(:get_container).and_return(container)
      allow(service_pod).to receive(:running?).and_return(false)
      allow(service_pod).to receive(:stopped?).and_return(true)
      expect(subject.wrapped_object).to receive(:ensure_stopped)
      expect(subject.wrapped_object).to receive(:get_container).and_return(container)
      expect(subject.ensure_desired_state).to eq container
    end

    it 'calls ensure_terminated if container exist and service_pod desired_state is terminated' do
      container = double(:container, :running? => true, :restarting? => false, name: 'foo-2')
      expect(subject.wrapped_object).to receive(:get_container).and_return(container)
      allow(service_pod).to receive(:terminated?).and_return(true)
      allow(service_pod).to receive(:running?).and_return(false)
      allow(service_pod).to receive(:stopped?).and_return(false)
      expect(subject.wrapped_object).to receive(:ensure_terminated)
      expect(subject.wrapped_object).to receive(:get_container).and_return(nil)
      expect(subject.ensure_desired_state).to be nil
    end

    it 'migrates container' do
      container = double(:container, :running? => true, :restarting? => false, name: 'foo-2')
      allow(subject.wrapped_object).to receive(:get_container).and_return(container)
      expect(subject.wrapped_object).to receive(:migrate_container).with(container)
      subject.ensure_desired_state
    end
  end

  describe '#state_in_sync' do
    let(:container) { instance_double(Docker::Container) }

    context "for a stopped service pod" do
      let(:service_pod) do
        Kontena::Models::ServicePod.new(
          'id' => 'foo/2',
          'instance_number' => 2,
          'updated_at' => Time.now.to_s,
          'deploy_rev' => Time.now.to_s,
          'desired_state' => 'stopped',
        )
      end

      it "returns true for a stopped container" do
        expect(container).to receive(:running?).and_return(false)

        expect(subject.state_in_sync?(service_pod, container)).to be_truthy
      end
    end
  end

  describe '#current_state' do
    it 'returns missing if container is not found' do
      expect(subject.current_state(nil)).to eq('missing')
    end

    it 'returns running if container is running' do
      container = double(:container, :running? => true)
      expect(subject.current_state(container)).to eq('running')
    end

    it 'returns restarting if restart is in progress' do
      container = double(:container, :running? => false)
      allow(subject.wrapped_object).to receive(:restarting?).and_return(true)
      expect(subject.current_state(container)).to eq('restarting')
    end

    it 'returns stopped if container is not running or restarting' do
      container = double(:container, :running? => false, :restarting? => false)
      expect(subject.current_state(container)).to eq('stopped')
    end
  end

  describe '#sync_state_to_master' do
    let(:container) { double(:container, :running? => true) }

    before(:each) do
      mock_rpc_client
    end

    it 'sends correct data' do
      expect(rpc_client).to receive(:request).with(
        '/node_service_pods/set_state',
        [node.id, hash_including(state: 'running', rev: service_pod.deploy_rev)]
      )
      subject.sync_state_to_master(service_pod, container)
    end

    it 'sends error' do
      expect(rpc_client).to receive(:request).with(
        '/node_service_pods/set_state',
        [node.id, hash_including(state: 'missing', rev: service_pod.deploy_rev, error: "Docker::Error::NotFoundError: No such image: redis:nonexist")]
      )
      subject.sync_state_to_master(service_pod, nil, Docker::Error::NotFoundError.new("No such image: redis:nonexist"))
    end

    context 'that has already updated' do
      before do
        expect(rpc_client).to receive(:request).with('/node_service_pods/set_state', [node.id, hash_including(rev: service_pod.deploy_rev)])
        subject.sync_state_to_master(service_pod, container)
      end

      it 'updates again with a diffrent state' do
        allow(container).to receive(:running?).and_return(false)
        expect(rpc_client).to receive(:request).with('/node_service_pods/set_state', [node.id, hash_including(rev: service_pod.deploy_rev, state: 'stopped')])
        subject.sync_state_to_master(service_pod, container)
      end

      it 'does not update again with the same state' do
        expect(rpc_client).to_not receive(:request)
        subject.sync_state_to_master(service_pod, container)
      end

      it 'updates again with a newer rev' do
        allow(service_pod).to receive(:deploy_rev).and_return((Time.now + 1.0).to_s)

        expect(rpc_client).to receive(:request)
        subject.sync_state_to_master(service_pod, container)
      end

      it 'does not send an update for an older rev' do
        allow(service_pod).to receive(:deploy_rev).and_return((Time.now - 1.0).to_s)

        expect(rpc_client).to_not receive(:request)
        subject.sync_state_to_master(service_pod, container)
      end
    end
  end

  describe '#needs_apply' do
    it 'returns true if container_state_changed is true' do
      expect(subject.needs_apply?(service_pod)).to be_truthy
    end

    it 'returns false if restarting and desired_state or deploy_rev has not changed' do
      allow(subject.wrapped_object).to receive(:restarting?).and_return(true)
      expect(subject.needs_apply?(service_pod)).to be_falsey
    end

    it 'returns true if restarting and deploy_rev has changed' do
      allow(subject.wrapped_object).to receive(:restarting?).and_return(true)
      subject.container_state_changed = false
      update = service_pod.dup
      allow(update).to receive(:deploy_rev).and_return('new')
      expect(subject.needs_apply?(update)).to be_truthy
    end

    it 'returns false if container_state_changed is false and pod has not changed' do
      subject.container_state_changed = false
      expect(subject.needs_apply?(service_pod)).to be_falsey
    end

    it 'returns true if container_state_changed is false and deploy_rev has changed' do
      subject.container_state_changed = false
      update = service_pod.dup
      allow(update).to receive(:deploy_rev).and_return('new')
      expect(subject.needs_apply?(update)).to be_truthy
    end

    it 'returns true if container_state_changed is false and desired_state has changed' do
      subject.container_state_changed = false
      update = service_pod.dup
      allow(update).to receive(:desired_state).and_return('stopped')
      expect(subject.needs_apply?(update)).to be_truthy
    end
  end

  describe '#check_deploy_rev' do
    it 'does nothing if passed service_pod deploy_rev is nil' do
      expect {
        update = service_pod.dup
        allow(update).to receive(:deploy_rev).and_return(nil)
        subject.check_deploy_rev(update)
      }.not_to change { subject.deploy_rev_changed? }
    end

    it 'does nothing if service_pod deploy_rev is nil' do
      expect {
        allow(service_pod).to receive(:deploy_rev).and_return(nil)
        update = service_pod.dup
        subject.check_deploy_rev(update)
      }.not_to change { subject.deploy_rev_changed? }
    end

    it 'changes if deploy_rev has changed' do
      expect {
        update = service_pod.dup
        allow(update).to receive(:deploy_rev).and_return('aaa')
        subject.check_deploy_rev(update)
      }.to change { subject.deploy_rev_changed? }.from(false).to(true)
    end
  end

  describe '#on_container_event' do
    before do
      subject.container_state_changed = false
    end

    context 'without any active container' do
      it 'ignores any events' do
        event = double(:event, id: '2b52d7ac3c70f4533a47d93cb81a8864eb2608705e0a986bdcced468f20e5025', status: 'start')

        expect {
          subject.on_container_event('container:event', event)
        }.not_to change { subject.container_state_changed }
      end
    end

    context 'with an active container' do
      let(:container) { double(:container, id: '2b52d7ac3c70f4533a47d93cb81a8864eb2608705e0a986bdcced468f20e5025') }

      before do
        subject.instance_variable_set('@container', container)
      end

      it 'ignores a mismatching event' do
        event = double(:event, id: 'f02a583a0dd44a685a14c445b9826b5f8a8c46555fabf003de3009180ff7a24c', status: 'start')

        expect {
          subject.on_container_event('container:event', event)
        }.not_to change { subject.container_state_changed }
      end

      it 'marks container state as changed' do
        event = double(:event, id: '2b52d7ac3c70f4533a47d93cb81a8864eb2608705e0a986bdcced468f20e5025', status: 'start')

        expect {
          subject.on_container_event('container:event', event)
        }.to change { subject.container_state_changed }.from(false).to(true)
      end

      it 'triggers restart logic on container die events' do
        event = double(:event, id: '2b52d7ac3c70f4533a47d93cb81a8864eb2608705e0a986bdcced468f20e5025', status: 'die')

        expect(subject.wrapped_object).to receive(:handle_restart_on_die)

        subject.on_container_event('container:event', event)
      end
    end
  end

  describe '#handle_restart_on_die' do
    it 'triggers restart without backoff by default if service_pod state is running' do
      allow(service_pod).to receive(:running?).and_return(true)
      expect(subject.wrapped_object).to receive(:after).with(0).once
      subject.handle_restart_on_die
    end

    it 'does not trigger restart if service_pod state is not running' do
      expect(subject.wrapped_object).not_to receive(:after)
      subject.handle_restart_on_die
    end

    it 'does not trigger restart if apply is in progress' do
      allow(subject.wrapped_object).to receive(:apply_in_progress?).and_return(true)
      expect(subject.wrapped_object).not_to receive(:after)
      subject.handle_restart_on_die
    end
  end

  describe '#service_container_outdated?' do
    let(:puller) { double(:puller) }
    let(:service_container) { double(:service_container) }

    before(:each) do
      allow(subject.wrapped_object).to receive(:container_outdated?).and_return(false)
      allow(subject.wrapped_object).to receive(:labels_outdated?).and_return(false)
      allow(subject.wrapped_object).to receive(:recreate_service_container?).and_return(false)
      allow(subject.wrapped_object).to receive(:image_outdated?).and_return(false)
      allow(puller).to receive(:ensure_image)
      allow(subject.wrapped_object).to receive(:image_puller).and_return(puller)
    end

    it 'returns false if container is up-to-date' do
      expect(subject.service_container_outdated?(service_container)).to be_falsey
    end

    it 'returns true if container is too old' do
      allow(subject.wrapped_object).to receive(:container_outdated?).and_return(true)
      expect(subject.service_container_outdated?(service_container)).to be_truthy
    end

    it 'returns true if labels need update' do
      allow(subject.wrapped_object).to receive(:labels_outdated?).and_return(true)
      expect(subject.service_container_outdated?(service_container)).to be_truthy
    end

    it 'returns true if service container needs to be recreated' do
      allow(subject.wrapped_object).to receive(:recreate_service_container?).and_return(true)
      expect(subject.service_container_outdated?(service_container)).to be_truthy
    end

    it 'returns true if deploy_rev has changed and service container image is outdated' do
      allow(subject.wrapped_object).to receive(:deploy_rev_changed?).and_return(true)
      allow(subject.wrapped_object).to receive(:image_outdated?).and_return(true)
      expect(puller).to receive(:ensure_image).with(service_pod.image_name, service_pod.deploy_rev, nil)
      expect(subject.service_container_outdated?(service_container)).to be_truthy
    end
  end

  describe '#container_outdated?' do
    it 'returns true if container created_at is older than service_pod updated_at' do
      service_container = double(:service_container,
        info: { 'Created' => (Time.now.utc - 120).to_s }
      )
      allow(service_pod).to receive(:updated_at).and_return((Time.now.utc - 60).to_s)
      expect(subject.container_outdated?(service_container)).to be_truthy
    end

    it 'returns false if container created_at is newer than service_pod updated_at' do
      service_container = double(:service_container,
        info: { 'Created' => (Time.now.utc - 20).to_s }
      )
      allow(service_pod).to receive(:updated_at).and_return((Time.now.utc - 60).to_s)
      expect(subject.container_outdated?(service_container)).to be_falsey
    end

    it 'fails if service_pod updated_at is too far in the future', log_celluloid_actor_crashes: false do
      service_container = double(:service_container,
        info: { 'Created' => (Time.now.utc - 20).to_s }
      )
      allow(service_pod).to receive(:updated_at).and_return((Time.now.utc + 60.0).to_s)
      expect{subject.container_outdated?(service_container)}.to raise_error(/service updated_at .* is in the future/)
    end

    it 'returns true if service_pod updated_at is slightly in the future' do
      service_container = double(:service_container,
        info: { 'Created' => (Time.now.utc - 0.5).to_s }
      )
      allow(service_pod).to receive(:updated_at).and_return((Time.now.utc + 0.5).to_s)
      expect(subject.container_outdated?(service_container)).to be_truthy
    end
  end

  describe '#image_outdated?' do
    it 'returns true if image id does not match to container' do
      image = double(:image, id: 'abc')
      service_container = double(:service_container,
        info: { 'Image' => 'bcd' }
      )
      allow(Docker::Image).to receive(:get).with(service_pod.image_name).and_return(image)
      expect(subject.image_outdated?(service_container)).to be_truthy
    end

    it 'returns false if image id matches to container' do
      image = double(:image, id: 'abc')
      service_container = double(:service_container,
        info: { 'Image' => 'abc' }
      )
      allow(Docker::Image).to receive(:get).with(service_pod.image_name).and_return(image)
      expect(subject.image_outdated?(service_container)).to be_falsey
    end
  end

  describe '#labels_outdated?' do
    it 'returns true when labels are outdated' do
      service_container = spy(:service_container,
        labels: { 'io.kontena.load_balancer.name' => 'lb'}
      )
      allow(service_pod).to receive(:labels).and_return({})
      expect(subject.labels_outdated?(service_container)).to be_truthy

      allow(service_pod).to receive(:labels).and_return({ 'io.kontena.load_balancer.name' => 'lb2' })
      expect(subject.labels_outdated?(service_container)).to be_truthy
    end

    it 'returns false with empty labels' do
      service_container = spy(:service_container,
        labels: {}
      )
      allow(service_pod).to receive(:labels).and_return({})
      expect(subject.labels_outdated?(service_container)).to be_falsey
    end

    it 'returns false with up-to-date labels' do
      service_container = spy(:service_container,
        labels: { 'io.kontena.load_balancer.name' => 'lb'}
      )
      allow(service_pod).to receive(:labels).and_return({ 'io.kontena.load_balancer.name' => 'lb' })
      expect(subject.labels_outdated?(service_container)).to be_falsey
    end
  end

  describe '#recreate_service_container?' do
    it 'returns false if container is running' do
      service_container = spy(:service_container,
        state: {'Running' => true}
      )
      expect(subject.recreate_service_container?(service_container)).to be_falsey
    end

    it 'returns false if container is stopped without error message' do
      service_container = spy(:service_container,
        state: {'Running' => false, 'Error' => ''}
      )
      expect(subject.recreate_service_container?(service_container)).to be_falsey
    end

    it 'returns true if container is stopped with error message' do
      service_container = spy(:service_container,
        running?: false,
        state: {'Running' => false, 'Error' => 'oh noes'}
      )
      expect(subject.recreate_service_container?(service_container)).to be_truthy
    end
  end
end

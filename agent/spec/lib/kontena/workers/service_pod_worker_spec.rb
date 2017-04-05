describe Kontena::Workers::ServicePodWorker do
  include RpcClientMocks

  let(:node) { Node.new('id' => 'aa') }
  let(:service_pod) do
    Kontena::Models::ServicePod.new(
      'id' => 'foo/2', 'instance_number' => 2,
      'updated_at' => Time.now.to_s, 'deploy_rev' => Time.now.to_s
    )
  end
  let(:subject) { described_class.new(node, service_pod) }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#ensure_desired_state' do
    before(:each) do
      mock_rpc_client
      allow(rpc_client).to receive(:request)
    end

    it 'calls ensure_running if container does not exist and service_pod desired_state is running' do
      allow(subject.wrapped_object).to receive(:get_container).and_return(nil)
      allow(service_pod).to receive(:running?).and_return(true)
      expect(subject.wrapped_object).to receive(:ensure_running)
      subject.ensure_desired_state
    end

    it 'calls ensure_running if container is not running and service_pod desired_state is running' do
      container = double(:container, :running? => false, :restarting? => false)
      allow(subject.wrapped_object).to receive(:get_container).and_return(container)
      allow(service_pod).to receive(:running?).and_return(true)
      expect(subject.wrapped_object).to receive(:ensure_started)
      subject.ensure_desired_state
    end

    it 'calls ensure_running if updated_at is newer than container' do
      container = double(:container,
        :running? => true, :restarting? => false,
        :info => { 'Created' => (Time.now - 30).to_s }
      )
      allow(subject.wrapped_object).to receive(:get_container).and_return(container)
      allow(service_pod).to receive(:running?).and_return(true)
      allow(service_pod).to receive(:service_rev).and_return(1)
      expect(subject.wrapped_object).to receive(:ensure_running)
      subject.ensure_desired_state
    end

    it 'calls ensure_stopped if container is running and service_pod desired_state is stopped' do
      container = double(:container, :running? => true, :restarting? => false)
      allow(subject.wrapped_object).to receive(:get_container).and_return(container)
      allow(service_pod).to receive(:running?).and_return(false)
      allow(service_pod).to receive(:stopped?).and_return(true)
      expect(subject.wrapped_object).to receive(:ensure_stopped)
      subject.ensure_desired_state
    end

    it 'calls ensure_terminated if container exist and service_pod desired_state is terminated' do
      container = double(:container, :running? => true, :restarting? => false)
      allow(subject.wrapped_object).to receive(:get_container).and_return(container)
      allow(service_pod).to receive(:terminated?).and_return(true)
      allow(service_pod).to receive(:running?).and_return(false)
      allow(service_pod).to receive(:stopped?).and_return(false)
      expect(subject.wrapped_object).to receive(:ensure_terminated)
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
      allow(subject.wrapped_object).to receive(:get_container).and_return(nil)
      expect(subject.current_state).to eq('missing')
    end

    it 'returns running if container is running' do
      container = double(:container, :running? => true)
      allow(subject.wrapped_object).to receive(:get_container).and_return(container)
      expect(subject.current_state).to eq('running')
    end

    it 'returns restarting if container is restarting' do
      container = double(:container, :running? => false, :restarting? => true)
      allow(subject.wrapped_object).to receive(:get_container).and_return(container)
      expect(subject.current_state).to eq('restarting')
    end

    it 'returns stopped if container is not running or restarting' do
      container = double(:container, :running? => false, :restarting? => false)
      allow(subject.wrapped_object).to receive(:get_container).and_return(container)
      expect(subject.current_state).to eq('stopped')
    end
  end

  describe '#sync_state_to_master' do
    before(:each) do
      mock_rpc_client
      allow(rpc_client).to receive(:request)
    end

    it 'sends correct data' do
      expect(rpc_client).to receive(:request).with(
        '/node_service_pods/set_state',
        [node.id, hash_including(state: 'running', rev: service_pod.deploy_rev)]
      )
      subject.sync_state_to_master('running')
    end

    it 'sends error' do
      expect(rpc_client).to receive(:request).with(
        '/node_service_pods/set_state',
        [node.id, hash_including(state: 'missing', rev: service_pod.deploy_rev, error: "Docker::Error::NotFoundError: No such image: redis:nonexist")]
      )
      subject.sync_state_to_master('missing', Docker::Error::NotFoundError.new("No such image: redis:nonexist"))
    end
  end
end

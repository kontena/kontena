describe Kontena::Workers::ServicePodManager, :celluloid => true do
  include RpcClientMocks

  let(:subject) { described_class.new(false) }
  let(:node) do
    Node.new(
      'id' => 'aaaa',
      'instance_number' => 2,
      'grid' => {}
    )
  end

  before(:each) do
    mock_rpc_client
    allow(subject.wrapped_object).to receive(:node).and_return(node)
  end

  describe '#populate_workers_from_master' do
    before(:each) do
      allow(subject.wrapped_object).to receive(:node).and_return(node)
      allow(subject.wrapped_object).to receive(:ensure_service_worker)
    end

    it 'calls terminate_workers' do
      allow(rpc_client).to receive(:request).with('/node_service_pods/list', [node.id]).and_return(
        {
          'service_pods' => [
            { 'id' => 'a/1', 'instance_number' => 1}
          ]
        }
      )
      expect(subject.wrapped_object).to receive(:terminate_workers).with(['a/1'])
      subject.populate_workers_from_master
    end

    it 'does not call terminate_workers if master returns something weird' do
      allow(rpc_client).to receive(:request).with('/node_service_pods/list', [node.id]).and_return(
        {
          'service_pods' => 'lolwtf'
        }
      )
      expect(subject.wrapped_object).to receive(:error).with(/Invalid response from master/)
      expect(subject.wrapped_object).not_to receive(:terminate_workers)
      expect(subject.wrapped_object).not_to receive(:ensure_service_worker)

      expect{subject.populate_workers_from_master}.not_to raise_error
    end

    it 'does not call terminate_workers if RPC fails' do
      allow(rpc_client).to receive(:request).with('/node_service_pods/list', [node.id]).and_raise(
        Kontena::RpcClient::Error.new(500, "random failure")
      )
      expect(subject.wrapped_object).to receive(:warn).with(/failed to get list of service pods from master/)
      expect(subject.wrapped_object).not_to receive(:terminate_workers)
      expect(subject.wrapped_object).not_to receive(:ensure_service_worker)

      subject.populate_workers_from_master
    end

    it 'calls ensure_service_worker for each service pod' do
      allow(rpc_client).to receive(:request).with('/node_service_pods/list', [node.id]).and_return(
        {
          'service_pods' => [
            { 'id' => 'a/1', 'instance_number' => 1},
            { 'id' => 'b/2', 'instance_number' => 2}
          ]
        }
      )
      expect(subject.wrapped_object).to receive(:ensure_service_worker) do |s|
        expect(s.id).to eq('a/1')
      end
      expect(subject.wrapped_object).to receive(:ensure_service_worker) do |s|
        expect(s.id).to eq('b/2')
      end
      subject.populate_workers_from_master
    end
  end

  describe '#populate_workers_from_docker' do
    it 'calls ensure_service_worker for each container' do
      allow(subject.wrapped_object).to receive(:fetch_containers).and_return([
        double(:a, id: 'a', service_id: 'foo', instance_number: 2, service_name: 'foo'),
        double(:b, id: 'b', service_id: 'bar', instance_number: 1, service_name: 'bar')
      ])
      expect(subject.wrapped_object).to receive(:ensure_service_worker).twice
      subject.populate_workers_from_docker
    end
  end

  describe '#terminate_workers' do
    it 'terminates workers that are not included in passed array' do
      workers = {
        'a/1' => Kontena::Workers::ServicePodWorker.new(node, double(:service_pod)),
        'b/3' => Kontena::Workers::ServicePodWorker.new(node, double(:service_pod))
      }
      allow(subject.wrapped_object).to receive(:workers).and_return(workers)
      expect(workers['a/1'].wrapped_object).to receive(:destroy).once
      expect(workers['b/3'].wrapped_object).not_to receive(:destroy)
      subject.terminate_workers(['b/3'])
      sleep 0.01
    end
  end

  describe '#finalize' do
    it 'terminates all workers' do
      workers = {
        'a/1' => Kontena::Workers::ServicePodWorker.new(node, double(:service_pod)),
        'b/3' => Kontena::Workers::ServicePodWorker.new(node, double(:service_pod))
      }
      allow(subject.wrapped_object).to receive(:workers).and_return(workers)
      subject.finalize
      expect(workers.all?{|id, w| !w.alive?}).to be_truthy
    end
  end
end

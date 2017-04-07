require_relative '../../spec_helper'

describe Rpc::NodeServicePodHandler do
  let(:grid) { Grid.create! }
  let(:subject) { described_class.new(grid) }
  let(:node) { HostNode.create!(grid: grid, name: 'test-node', node_id: 'abc') }

  describe '#list' do
    before(:each) do
      allow(subject).to receive(:migration_done?).and_return(true)
    end

    it 'fails if node does not exist' do
      expect{subject.list('foo')}.to raise_error RuntimeError, 'Node not found'
    end

    it 'fails if migration is not done' do
      expect(subject).to receive(:migration_done?).and_return(false)

      expect{subject.list(node.node_id)}.to raise_error RuntimeError, 'Migration not done'
    end

    it 'returns hash with service pods' do
      service = grid.grid_services.create!(name: 'foo', image_name: 'foo/bar:latest')
      service.grid_service_instances.create!(instance_number: 1, host_node: node, desired_state: 'running')
      list = subject.list(node.node_id)
      expect(list[:service_pods][0]).to include(
        instance_number: 1,
        desired_state: 'running'
      )
    end

    it 'does not return service pods from other node' do
      other_node = HostNode.create!(grid: grid, name: 'other-node', node_id: 'def')
      service = grid.grid_services.create!(name: 'foo', image_name: 'foo/bar:latest')
      service.grid_service_instances.create!(instance_number: 1, host_node: node, desired_state: 'running')
      list = subject.list(other_node.node_id)
      expect(list[:service_pods]).to eq([])
    end
  end

  describe '#set_state' do
    let(:service) { grid.grid_services.create!(name: 'foo', image_name: 'foo/bar:latest') }
    let(:service_instance) do
      service.grid_service_instances.create!(
        instance_number: 2, host_node: node, desired_state: 'running'
      )
    end

    let(:data) do
      {
        'state' => 'running', 'rev' => Time.now.to_s,
        'service_id' => service.id.to_s, 'instance_number' => service_instance.instance_number
      }
    end

    it 'saves service pod state to service instance' do
      subject.set_state(node.node_id, data)
      service_instance.reload

      expect(service_instance.rev).to eq(data['rev'])
      expect(service_instance.state).to eq(data['state'])
    end

    it 'fails if node not found' do
      expect{subject.set_state('notvalid', data)}.to raise_error 'Node not found'
    end

    it 'fail if service instance not found' do
      data['instance_number'] = 3
      expect{subject.set_state(node.node_id, data)}.to raise_error 'Instance not found'
    end
  end

  describe '#event' do
    let(:service) { grid.grid_services.create!(name: 'foo', image_name: 'foo/bar:latest') }

    let(:service_instance) do
      service.grid_service_instances.create!(
        instance_number: 2, host_node: node, desired_state: 'running'
      )
    end

    let(:data) do
      {
        'reason' => 'service:instance_create',
        'data' => 'hello',
        'service_id' => service.id.to_s,
        'instance_number' => service_instance.instance_number
      }
    end

    it 'saves event' do
      expect {
        subject.event(node.node_id, data)
      }.to change { service.event_logs.count }.by(1)
    end

    it 'returns nil if node not found' do
      expect(subject.event('invalid', data)).to be_nil
    end
  end

  describe '#migration_done?' do
    it 'returns false if migrations are not recent enough' do
      expect(subject.migration_done?).to be_falsey
    end
  end
end

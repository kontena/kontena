require_relative '../../spec_helper'

describe Rpc::NodeServicePodHandler, celluloid: true do
  let(:grid) { Grid.create! }
  let(:subject) { described_class.new(grid) }
  let(:node) { HostNode.create!(grid: grid, name: 'test-node', node_id: 'abc') }

  describe '#list' do
    it 'returns hash with error if id does not exist' do
      list = subject.list('foo')
      expect(list[:error]).not_to be_nil
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
end

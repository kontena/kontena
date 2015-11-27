require_relative '../../../spec_helper'

describe Scheduler::Strategy::HighAvailability do

  let(:grid) { Grid.create(name: 'test') }

  let(:nodes) do
    nodes = []
    nodes << HostNode.create!(node_id: 'node1', name: 'node-1', connected: true, grid: grid)
    nodes << HostNode.create!(node_id: 'node2', name: 'node-2', connected: true, grid: grid)
    nodes << HostNode.create!(node_id: 'node3', name: 'node-3', connected: true, grid: grid)
    nodes
  end

  let(:stateful_service) do
    GridService.create!(name: 'test', grid: grid, image_name: 'foo/bar:latest', stateful: true)
  end

  let(:stateless_service) do
    GridService.create!(name: 'test', grid: grid, image_name: 'foo/bar:latest', stateful: false)
  end

  describe '#find_node' do
    context 'stateful service' do
      it 'returns node that does not yet have service instance' do
        nodes[1].schedule_counter = 1
        expect(subject.find_node(stateful_service, 2, nodes)).not_to eq(nodes[1])
        nodes[0].schedule_counter = 1
        expect(subject.find_node(stateful_service, 3, nodes)).to eq(nodes[2])
      end

      it 'returns node that has data volume container' do
        stateful_service.containers.create!(name: 'test-3-volumes', host_node: nodes[2], container_type: 'volume', container_id: 'aa')
        expect(subject.find_node(stateful_service, 3, nodes)).to eq(nodes[2])
      end

      it 'return nil if data volume node is not available' do
        node4 = HostNode.create!(node_id: 'node4', name: 'node-4', connected: true, grid: grid)
        stateful_service.containers.create!(name: 'test-3-volumes', host_node: node4, container_type: 'volume', container_id: 'aa')
        expect(subject.find_node(stateful_service, 3, nodes)).to be_nil
      end
    end

    context 'stateless service' do
      it 'returns node that does not yet have service instance' do
        nodes[1].schedule_counter = 1
        expect(subject.find_node(stateful_service, 2, nodes)).not_to eq(nodes[1])
        nodes[0].schedule_counter = 1
        expect(subject.find_node(stateful_service, 3, nodes)).to eq(nodes[2])
      end
    end
  end
end

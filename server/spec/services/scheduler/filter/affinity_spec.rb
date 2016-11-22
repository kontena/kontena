require_relative '../../../spec_helper'

describe Scheduler::Filter::Affinity do

  let(:grid) { Grid.create(name: 'test') }
  let(:nodes) do
    nodes = []
    nodes << HostNode.create!(grid: grid, node_id: 'node1', name: 'node-1', labels: ['az-1', 'ssd'])
    nodes << HostNode.create!(grid: grid, node_id: 'node2', name: 'node-2', labels: ['az-1', 'hdd'])
    nodes << HostNode.create!(grid: grid, node_id: 'node3', name: 'node-3', labels: ['az-2', 'ssd'])
    nodes
  end

  describe '#for_service' do
    it 'returns all nodes if service does not have any affinities defined' do
      service = double(:service, affinity: [])
      filtered = subject.for_service(service, 1, nodes)
      expect(filtered).to eq(nodes)
    end

    context 'node' do
      it 'returns node-1 if affinity: node==node-1' do
        service = double(:service, affinity: ['node==node-1'])
        filtered = subject.for_service(service, 1, nodes)
        expect(filtered.size).to eq(1)
        expect(filtered).to eq([nodes[0]])
      end

      it 'returns node-1 if affinity: node!=node-2,node!=node-3' do
        service = double(:service, affinity: ['node!=node-2', 'node!=node-3'])
        filtered = subject.for_service(service, 1, nodes)
        expect(filtered.size).to eq(1)
        expect(filtered).to eq([nodes[0]])
      end

      it 'does not return node-3 if affinity: node!=node-3' do
        service = double(:service, affinity: ['node!=node-3'])
        filtered = subject.for_service(service, 1, nodes)
        expect(filtered.size).to eq(2)
        expect(filtered).to eq(nodes - [nodes[2]])
      end
    end

    context 'label' do
      it 'returns node-1 & node-3 if affinity: label==ssd' do
        service = double(:service, affinity: ['label==ssd'])
        filtered = subject.for_service(service, 1, nodes)
        expect(filtered.size).to eq(2)
        expect(filtered).to include(nodes[0])
        expect(filtered).to include(nodes[2])
      end

      it 'returns node-2 if affinity: label!=ssd' do
        service = double(:service, affinity: ['label!=ssd'])
        filtered = subject.for_service(service, 1, nodes)
        expect(filtered.size).to eq(1)
        expect(filtered).to include(nodes[1])
      end

      it 'returns none if node labels are nil' do
        nodes.each{|n| n.labels = nil}
        service = double(:service, affinity: ['label==ssd'])
        filtered = subject.for_service(service, 1, nodes)
        expect(filtered.size).to eq(0)
      end
    end

    context 'container' do
      let(:service) { GridService.create!(grid: grid, name: 'redis', image_name: 'redis:2.8')}

      before(:each) do
        service.containers.create!(
          name: 'redis-1', host_node: nodes[0], instance_number: 1,
          labels: {
            'io;kontena;container;name' => 'redis-1',
            'io;kontena;service;name' => 'redis'
          }
        )
        service.containers.create!(
          name: 'redis-2', host_node: nodes[1], instance_number: 2,
          labels: {
            'io;kontena;container;name' => 'redis-2',
            'io;kontena;service;name' => 'redis'
          }
        )
      end

      it 'returns node-1 if affinity: container==redis-1' do
        service.affinity = ['container==redis-1']
        filtered = subject.for_service(service, 1, nodes)
        expect(filtered.size).to eq(1)
        expect(filtered).to eq([nodes[0]])
      end

      it 'returns node-2 if affinity: container==redis-%i and current container name is app-2' do
        service = double(:service, affinity: ['container==redis-%i'])
        filtered = subject.for_service(service, 2, nodes)
        expect(filtered.size).to eq(1)
        expect(filtered).to eq([nodes[1]])
      end

      it 'does not return node-2 if affinity: container!=redis-2' do
        service = double(:service, affinity: ['container!=redis-2'])
        filtered = subject.for_service(service, 1, nodes)
        expect(filtered.size).to eq(2)
        expect(filtered).to eq(nodes - [nodes[1]])
      end
    end

    context 'service' do
      let(:redis_service) { GridService.create!(grid: grid, name: 'redis', image_name: 'redis:2.8')}

      before(:each) do
        redis_service.containers.create!(
          name: 'redis-1', host_node: nodes[0], instance_number: 1,
          labels: {
            'io;kontena;service;name' => 'redis'
          }
        )
        redis_service.containers.create!(
          name: 'redis-2', host_node: nodes[2], instance_number: 2,
          labels: {
            'io;kontena;service;name' => 'redis'
          }
        )
      end

      it 'returns node-1 if affinity: service==redis' do
        service = double(:service, affinity: ['service==redis'])
        filtered = subject.for_service(service, 1, nodes)
        expect(filtered.size).to eq(2)
        expect(filtered).to eq([nodes[0], nodes[2]])
      end

      it 'does not return node-2 if affinity: service!=redis' do
        service = double(:service, affinity: ['service!=redis'])
        filtered = subject.for_service(service, 1, nodes)
        expect(filtered.size).to eq(1)
        expect(filtered).to eq([nodes[1]])
      end
    end
  end
end

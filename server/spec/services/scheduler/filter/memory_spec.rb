require_relative '../../../spec_helper'

describe Scheduler::Filter::Memory do

  let(:nodes) do
    nodes = []
    nodes << HostNode.create!(node_id: 'node1', name: 'node-1')
    nodes << HostNode.create!(node_id: 'node2', name: 'node-2')
    nodes << HostNode.create!(node_id: 'node3', name: 'node-3')
    nodes
  end

  let(:grid) { Grid.create(name: 'test') }

  let(:test_service) {
    GridService.create(name: 'test-service', grid: grid, image_name: 'test-service:latest')
  }

  describe '#for_service' do
    it 'returns all nodes if memory consumption cannot be calculated' do
      filtered = subject.for_service(test_service, 'test-service-1', nodes)
      expect(filtered).to eq(nodes)
    end

    it 'returns all nodes if service instance memory stats are not available' do
      nodes.each{|n| n.update_attribute(:mem_total, 1.gigabytes) }
      test_service.containers.create(name: 'test-service-1')
      filtered = subject.for_service(test_service, 'test-service-1', nodes)
      expect(filtered).to eq(nodes)
    end

    it 'returns none of the nodes if node memory is not available' do
      test_service.update_attribute(:memory, 512.megabytes)
      filtered = subject.for_service(test_service, 'test-service-1', nodes)
      expect(filtered).to eq([])
    end
  end


  describe '#reject_candidate?' do
    let(:candidate) {
      candidate = nodes[0]
      candidate.mem_total = 1.gigabytes
      candidate
    }

    it 'rejects candidate if node does not have enough total memory' do
      reject = subject.reject_candidate?(
        candidate, 1300.megabytes, test_service, 1
      )
      expect(reject).to be_truthy
    end

    it 'rejects candidate if it does not have enough memory available' do
      candidate.host_node_stats.create!(
        memory: {
          'total' => 1.gigabytes,
          'free' => 128.megabytes,
          'cached' => 128.megabytes,
          'buffers' => 128.megabytes
        }
      )
      reject = subject.reject_candidate?(
        candidate, 500.megabytes, test_service, 1
      )
      expect(reject).to be_truthy
    end

    it 'accepts candidate if there is enough free memory' do
      candidate.host_node_stats.create!(
        memory: {
          'total' => 1.gigabytes,
          'free' => 512.megabytes,
          'cached' => 128.megabytes,
          'buffers' => 128.megabytes
        }
      )
      reject = subject.reject_candidate?(
        candidate, 500.megabytes, test_service, 1
      )
      expect(reject).to be_falsey
    end

    it 'accepts candidate if there is enough memory to swap service instance' do
      candidate.host_node_stats.create!(
        memory: {
          'total' => 1.gigabytes,
          'free' => 128.megabytes,
          'cached' => 128.megabytes,
          'buffers' => 128.megabytes
        }
      )
      service_instance = test_service.containers.create!(
        name: 'test-service-1',
        host_node: candidate,
        labels: {
          'io;kontena;service;id' => test_service.id.to_s,
          'io;kontena;service;instance_number' => '1'
        }
      )
      reject = subject.reject_candidate?(
        candidate, 500.megabytes, test_service, 1
      )
      expect(reject).to be_falsey
    end
  end
end

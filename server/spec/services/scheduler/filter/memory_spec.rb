
describe Scheduler::Filter::Memory do
  let(:grid) { Grid.create(name: 'test') }
  let(:nodes) { [
    grid.create_node!('node-1', node_id: 'node1'),
    grid.create_node!('node-2', node_id: 'node2'),
    grid.create_node!('node-3', node_id: 'node3'),
  ] }

  let(:test_service) {
    GridService.create(name: 'test-service', grid: grid, image_name: 'test-service:latest')
  }

  describe '#for_service' do
    it 'returns all nodes if memory consumption cannot be calculated' do
      filtered = subject.for_service(test_service, 1, nodes)
      expect(filtered).to eq(nodes)
    end

    it 'returns all nodes if service instance memory stats are not available' do
      nodes.each{|n| n.update_attribute(:mem_total, 1.gigabytes) }
      test_service.containers.create(name: 'test-service-1')
      filtered = subject.for_service(test_service, 1, nodes)
      expect(filtered).to eq(nodes)
    end

    it 'returns none of the nodes if node memory is not available' do
      test_service.update_attribute(:memory, 512.megabytes)
      expect{subject.for_service(test_service, 1, nodes)}.to raise_error(Scheduler::Error)
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
        instance_number: 1
      )
      reject = subject.reject_candidate?(
        candidate, 500.megabytes, test_service, 1
      )
      expect(reject).to be_falsey
    end

    it 'accepts candidate if it is a replacement and stats are missing' do
      candidate.host_node_stats.create!(
        memory: {
          'total' => 0,
          'free' => 0,
          'cached' => 0,
          'buffers' => 0
        }
      )
      service_instance = test_service.containers.create!(
        name: 'test-service-1',
        host_node: candidate,
        instance_number: 1
      )
      reject = subject.reject_candidate?(
        candidate, 500.megabytes, test_service, 1
      )
      expect(reject).to be_falsey
    end
  end
end

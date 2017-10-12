
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
    it 'returns all nodes with default memory available if memory consumption cannot be calculated' do
      nodes.each{|n| n.update_attribute(:mem_total, 384.megabytes) }
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
      candidate.latest_stats = {
        'memory' => {
          'total' => 1.gigabytes,
          'free' => 128.megabytes,
          'cached' => 128.megabytes,
          'buffers' => 128.megabytes
        }
      }
      reject = subject.reject_candidate?(
        candidate, 500.megabytes, test_service, 1
      )
      expect(reject).to be_truthy
    end

    it 'accepts candidate if there is enough free memory' do
      candidate.latest_stats = {
        'memory' => {
          'total' => 1.gigabytes,
          'free' => 512.megabytes,
          'cached' => 128.megabytes,
          'buffers' => 128.megabytes
        }
      }
      reject = subject.reject_candidate?(
        candidate, 500.megabytes, test_service, 1
      )
      expect(reject).to be_falsey
    end

    it 'accepts candidate if there is enough memory to swap service instance' do
      candidate.latest_stats = {
        'memory' => {
          'total' => 1.gigabytes,
          'free' => 128.megabytes,
          'cached' => 128.megabytes,
          'buffers' => 128.megabytes
        }
      }
      test_service.grid_service_instances.create!(
        host_node: candidate,
        instance_number: 1
      )
      reject = subject.reject_candidate?(
        candidate, 500.megabytes, test_service, 1
      )
      expect(reject).to be_falsey
    end

    it 'accepts candidate if it is a replacement and stats are missing' do
      candidate.latest_stats = {
        'memory' => {
          'total' => 0,
          'free' => 0,
          'cached' => 0,
          'buffers' => 0
        }
      }
      test_service.grid_service_instances.create!(
        host_node: candidate,
        instance_number: 1
      )
      reject = subject.reject_candidate?(
        candidate, 500.megabytes, test_service, 1
      )
      expect(reject).to be_falsey
    end
  end

  describe '#resolve_memory_from_stats' do
    let(:candidate) {
      candidate = nodes[0]
      candidate.mem_total = 1.gigabytes
      candidate
    }

    it 'returns zero if stats are empty' do
      test_service.grid_service_instances.create!(
        host_node: candidate,
        instance_number: 1
      )
      expect(subject.resolve_memory_from_stats(test_service, 1)).to eq(0)
    end

    it 'returns memory (+ 25%) if stats found' do
      test_service.grid_service_instances.create!(
        host_node: candidate,
        instance_number: 1,
        latest_stats: {
          'memory' => { 'usage' => 34.megabytes }
        }
      )
      expect(subject.resolve_memory_from_stats(test_service, 1)).to eq(34.megabytes * 1.25)
    end
  end
end

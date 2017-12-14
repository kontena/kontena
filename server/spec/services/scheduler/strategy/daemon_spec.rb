
describe Scheduler::Strategy::Daemon do

  let(:grid) { Grid.create(name: 'test') }

  let(:host_node_count) { 10 }
  let(:host_nodes) do
    host_node_count.times.map do |i|
      n = i + 1
      HostNode.create!(
        node_id: "node#{n}", name: "node-#{n}", connected: true, grid: grid, node_number: n
      )
    end
  end

  let(:scheduler_nodes) do
    host_nodes.map{|n| Scheduler::Node.new(n)}
  end

  let(:container_count) { 1 }

  let(:stateless_service) do
    GridService.create!(name: 'test', grid: grid, image_name: 'foo/bar:latest', stateful: false, container_count: container_count)
  end

  describe '#find_node' do
    it 'finds matching nodes' do
      nodes = scheduler_nodes
      nodes.each do |n|
        node = subject.find_node(stateless_service, n.node_number, nodes)
        node.scheduled_instance! n.node_number
        expect(node).to eq(nodes[n.node_number - 1])
      end
    end

    context 'with existing nodes' do
      before(:each) do
        host_nodes.each do |n|
          container_count.times do |i|
            si = stateless_service.grid_service_instances.create!(
              host_node: n,
              instance_number: (i * host_nodes.size) + n.node_number,
            )
          end
        end
      end

      it 'minimizes shuffle' do
        nodes = scheduler_nodes

        scheduled = []
        nodes.each_with_index do |n, i|
          node = subject.find_node(stateless_service, i + 1, nodes)
          node.scheduled_instance! i + 1
          scheduled << node
        end
        expect(scheduled.map {|s| s.node_number}).to eq([
          1, 2, 3, 4, 5, 6, 7, 8, 9, 10
        ])
      end

      context "with 2 instances per node" do
        let(:container_count) { 2 }

        it 'minimizes shuffle when nodes 2 & 3 are missing' do
          nodes = scheduler_nodes.tap do |n|
            n.delete_at(1)
            n.delete_at(1)
          end

          scheduled = []
          (nodes.size * container_count).times do |i|
            node = subject.find_node(stateless_service, i + 1, nodes)
            node.scheduled_instance! i + 1
            scheduled << node
          end
          expect(scheduled.map {|s| s.node_number}).to eq([
            1, 7, 8, 4, 5, 6, 7, 8, 9, 10,
            1, 9, 10, 4, 5, 6
          ])
        end
      end

      context "with 3 instances per node" do
        let(:container_count) { 3 }

        it 'minimizes shuffle when nodes 2 & 3 are missing' do
          nodes = scheduler_nodes.tap do |n|
            n.delete_at(1)
            n.delete_at(1)
          end

          scheduled = []
          (nodes.size * container_count).times do |i|
            node = subject.find_node(stateless_service, i + 1, nodes)
            node.scheduled_instance! i + 1
            scheduled << node
          end
          expect(scheduled.map {|s| s.node_number}).to eq([
            1, 5, 6, 4, 5, 6, 7, 8, 9, 10,
            1, 7, 8, 4, 5, 6, 7, 8, 9, 10,
            1, 9, 10, 4,
            ])
        end
      end


      it 'minimizes shuffle when last two nodes are missing' do
        nodes = scheduler_nodes[0..-3]
        scheduled = []
        nodes.each_with_index do |n, i|
          node = subject.find_node(stateless_service, i + 1, nodes)
          node.scheduled_instance! i + 1
          scheduled << node
        end
        expect(scheduled.map {|s| s.node_number}).to eq([
          1, 2, 3, 4, 5, 6, 7, 8
        ])
      end
    end

    context 'with existing re-distributed instances' do
      let(:host_node_count) { 3 }
      let(:container_count) { 2 }

      before(:each) do
        stateless_service.grid_service_instances.create!(host_node: host_nodes[2], instance_number: 1)
        stateless_service.grid_service_instances.create!(host_node: host_nodes[1], instance_number: 2)
        stateless_service.grid_service_instances.create!(host_node: host_nodes[0], instance_number: 3)
        stateless_service.grid_service_instances.create!(host_node: host_nodes[0], instance_number: 4)
        stateless_service.grid_service_instances.create!(host_node: host_nodes[1], instance_number: 5)
        stateless_service.grid_service_instances.create!(host_node: host_nodes[2], instance_number: 6)
      end

      it 'schedules the instances evenly' do
        nodes = scheduler_nodes.tap do |n|
          n.delete_at(1)
        end

        scheduled = []
        (nodes.size * container_count).times do |i|
          node = subject.find_node(stateless_service, i + 1, nodes)
          node.scheduled_instance! i + 1
          scheduled << node
        end
        expect(scheduled.map {|s| s.node_number}).to eq([
          3, 3, 1, 1,
        ])
      end
    end

    context 'with newly added nodes and increased container count' do
      let(:host_node_count) { 3 }
      let(:container_count) { 2 }

      before(:each) do
        stateless_service.grid_service_instances.create!(host_node: host_nodes[0], instance_number: 1)
        stateless_service.grid_service_instances.create!(host_node: host_nodes[1], instance_number: 2)
      end

      it 'schedules the instances evenly' do
        nodes = scheduler_nodes

        scheduled = []
        (nodes.size * container_count).times do |i|
          node = subject.find_node(stateless_service, i + 1, nodes)
          node.scheduled_instance! i + 1
          scheduled << node
        end
        expect(scheduled.map {|s| s.node_number}).to eq([
          1, 2, 3, 1, 2, 3
        ])
      end
    end

    context 'with newly added nodes and high container count' do
      let(:host_node_count) { 3 }
      let(:container_count) { 2 }

      before(:each) do
        stateless_service.grid_service_instances.create!(host_node: host_nodes[0], instance_number: 1)
        stateless_service.grid_service_instances.create!(host_node: host_nodes[1], instance_number: 2)
        stateless_service.grid_service_instances.create!(host_node: host_nodes[0], instance_number: 3)
        stateless_service.grid_service_instances.create!(host_node: host_nodes[1], instance_number: 4)
      end

      it 'schedules the instances evenly' do
        nodes = scheduler_nodes

        scheduled = []
        (nodes.size * container_count).times do |i|
          node = subject.find_node(stateless_service, i + 1, nodes)
          node.scheduled_instance! i + 1
          scheduled << node
        end
        expect(scheduled.map {|s| s.node_number}).to eq([
          1, 2, 1, 2, 3, 3
        ])
      end
    end

    context 'with newly added nodes' do
      before(:each) do
        host_nodes[0..-3].each do |n|
          stateless_service.grid_service_instances.create!(
            host_node: n,
            instance_number: n.node_number
          )
        end
      end

      it 'finds correct nodes' do
        nodes = scheduler_nodes
        scheduled = []
        nodes.each_with_index do |n, i|
          node = subject.find_node(stateless_service, i + 1, nodes)
          node.scheduled_instance! i + 1
          scheduled << node
        end
        expect(scheduled.map { |s| s.node_number}).to eq([
          1, 2, 3, 4, 5, 6, 7, 8, 9, 10
        ])
      end
    end
  end

  describe '#instance_count' do
    it 'returns node count multiplied with instance count' do
      expect(subject.instance_count(3, 2)).to eq(6)
    end
  end

  describe '#sort_candidates' do
    it 'sorts by node_number by default' do
      expect(subject.sort_candidates(scheduler_nodes.shuffle, stateless_service, 1)).to eq(scheduler_nodes)
    end
  end
end

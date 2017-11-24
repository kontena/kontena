
describe Scheduler::Filter::Affinity do

  let(:grid) { Grid.create(name: 'test') }
  let(:nodes) { [
    grid.create_node!('node-1', node_id: 'node1', labels: ['az-1', 'ssd']),
    grid.create_node!('node-2', node_id: 'node2', labels: ['az-1', 'hdd']),
    grid.create_node!('node-3', node_id: 'node3', labels: ['az-2', 'ssd']),
  ] }

  describe '#split_affinity' do
    it "raises for an invalid comperator" do
      expect{subject.split_affinity('foo=bar')}.to raise_error(Scheduler::Error, /Invalid affinity filter: foo=bar/)
    end

    it "returns three parts for eq" do
      expect(subject.split_affinity('foo==bar')).to eq ['foo', '==', 'bar']
    end

    it "returns three parts for soft eq" do
      expect(subject.split_affinity('foo==~bar')).to eq ['foo', '==~', 'bar']
    end

    it "returns three parts for neq" do
      expect(subject.split_affinity('foo!=bar')).to eq ['foo', '!=', 'bar']
    end

    it "returns three parts for soft neq" do
      expect(subject.split_affinity('foo!=~bar')).to eq ['foo', '!=~', 'bar']
    end
  end

  describe '#hard_affinities' do
    it 'returns empty array if no hard affinities' do
      expect(subject.hard_affinities(['foo==~bar'])).to eq([])
    end

    it 'returns hard affinities' do
      affinities = ['foo==bar', 'foo!=bar', 'bar==~baz', 'bar!=~baz']
      expect(subject.hard_affinities(affinities)).to eq(['foo==bar', 'foo!=bar'])
    end
  end

  describe '#soft_affinities' do
    it 'returns empty array if no soft affinities' do
      expect(subject.soft_affinities(['foo==bar'])).to eq([])
    end

    it 'returns soft affinities' do
      affinities = ['foo==bar', 'foo!=bar', 'bar==~baz', 'bar!=~baz']
      expect(subject.soft_affinities(affinities)).to eq(['bar==~baz', 'bar!=~baz'])
    end
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
        expect{subject.for_service(service, 1, nodes)}.to raise_error(Scheduler::Error)
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
        redis_service.grid_service_instances.create!(
          host_node: nodes[0],
          instance_number: 1
        )
        redis_service.grid_service_instances.create!(
          host_node: nodes[2],
          instance_number: 2
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

    context 'soft affinity' do
      it 'returns matching node' do
        service = double(:service, affinity: ['label==~hdd'])
        filtered = subject.for_service(service, 1, nodes)
        expect(filtered.size).to eq(1)
        expect(filtered).to eq([nodes[1]])
      end

      it 'returns all nodes if affinity does not match any' do
        service = double(:service, affinity: ['label==~gpu'])
        filtered = subject.for_service(service, 1, nodes)
        expect(filtered.size).to eq(3)
        expect(filtered).to eq(nodes)
      end

      it 'returns matching node based on hard-affinity if soft-affinity does not match any' do
        service = double(:service, affinity: ['label==az-2', 'label==~gpu'])
        filtered = subject.for_service(service, 1, nodes)
        expect(filtered.size).to eq(1)
        expect(filtered).to eq([nodes[2]])
      end
    end

    it "raises on unknown affinity filter" do
      service = double(:service, affinity: ['nodes==test'])
      expect{subject.for_service(service, 1, nodes)}.to raise_error(StandardError, /Unknown affinity filter: nodes/)
    end

    it "raises on invalid affinity filter" do
      service = double(:service, affinity: ['foo=bar'])
      expect{subject.for_service(service, 1, nodes)}.to raise_error(StandardError, /Invalid affinity filter: foo=bar/)
    end
  end
end


describe Scheduler::Filter::Dependency do

  let(:grid) { Grid.create(name: 'test') }
  let(:nodes) do
    nodes = []
    nodes << grid.create_node!('node-1', node_id: 'node1', labels: ['az-1', 'ssd'], grid: grid)
    nodes << grid.create_node!('node-2', node_id: 'node2', labels: ['az-1', 'hdd'], grid: grid)
    nodes << grid.create_node!('node-3', node_id: 'node3', labels: ['az-2', 'ssd'], grid: grid)
    nodes
  end
  let(:default_stack) {
    grid.stacks.find_by(name: 'null')
  }
  let(:mysql_stack) {
    grid.stacks.create(name: 'mysql')
  }
  let(:mysql_service) {
    GridService.create(
      name: 'mysql',
      image_name: 'mysql:latest',
      grid: grid,
      stack: default_stack
    )
  }
  let(:logstash_service) {
    GridService.create!(
      name: 'logstash',
      image_name: 'logstash:latest',
      grid: grid,
      stack: default_stack
    )
  }
  let(:mysql_mysql_service) {
    GridService.create(
      name: 'mysql',
      image_name: 'mysql:latest',
      grid: grid,
      stack: mysql_stack
    )
  }
  let(:mysql_logstash_service) {
    GridService.create!(
      name: 'logstash',
      image_name: 'logstash:latest',
      grid: grid,
      stack: mysql_stack
    )
  }

  describe '#filter_candidates_by_volume' do
    it 'finds no candidates if no volumes match' do
      logstash_service.volumes_from = ['mysql-service-%s']
      expect{subject.filter_candidates_by_volume(nodes, logstash_service, 2)}.to raise_error(Scheduler::Error)
    end

    it 'returns correct candidates for service that belongs to default stack' do
      mysql_service.containers.create(
        host_node: nodes[1],
        container_id: 'asdadasdssad',
        name: 'null-mysql-2',
        instance_number: 2
      )
      logstash_service.volumes_from = ['mysql-%s']
      candidates = nodes.dup
      subject.filter_candidates_by_volume(candidates, logstash_service, 2)
      expect(candidates).to eq([nodes[1]])
    end

    it 'returns correct candidates for legacy service that belongs to default stack' do
      mysql_service.containers.create(
        host_node: nodes[1],
        container_id: 'asdadasdssad',
        name: 'mysql-2',
        instance_number: 2,
        labels: {}
      )
      logstash_service.volumes_from = ['mysql-%s']
      candidates = nodes.dup
      subject.filter_candidates_by_volume(candidates, logstash_service, 2)
      expect(candidates).to eq([nodes[1]])
    end

    it 'returns correct candidates for service that belongs to custom stack' do
      mysql_mysql_service.containers.create(
        host_node: nodes[2],
        container_id: 'asdadasdssad',
        name: 'mysql-mysql-3',
        instance_number: 3,
        labels: {
          'io;kontena;stack;name' => 'mysql'
        }
      )
      mysql_logstash_service.volumes_from = ['mysql-%s']
      candidates = nodes.dup
      subject.filter_candidates_by_volume(candidates, mysql_logstash_service, 3)
      expect(candidates).to eq([nodes[2]])
    end

    it 'returns no candidates for service has no matching volumes_from' do
      mysql_mysql_service.containers.create(
        host_node: nodes[2],
        container_id: 'asdadasdssad',
        name: 'mysql-mysql-3',
        instance_number: 3,
        labels: {
          'io;kontena;stack;name' => 'mysql'
        }
      )
      mysql_logstash_service.volumes_from = ['foo-%s']
      candidates = nodes.dup
      expect{subject.filter_candidates_by_volume(candidates, mysql_logstash_service, 3)}.to raise_error(Scheduler::Error)
    end
  end

  describe '#filter_by_volume?' do
    it 'returns true if service has volumes_from' do
      logstash_service.volumes_from = ['mysql-service-%s']
      expect(subject.filter_by_volume?(logstash_service)).to eq(true)
    end

    it 'returns false if service has no volumes_from' do
      expect(subject.filter_by_volume?(logstash_service)).to eq(false)
    end
  end

  describe '#filter_by_net?' do
    it 'returns true if service network points to container' do
      logstash_service.net = 'container:mysql_service-%s'
      expect(subject.filter_by_net?(logstash_service)).to eq(true)
    end

    it 'returns false if service net is host' do
      logstash_service.net = 'host'
      expect(subject.filter_by_net?(logstash_service)).to eq(false)
    end

    it 'returns false if service has no network setting' do
      expect(subject.filter_by_net?(logstash_service)).to eq(false)
    end
  end
end

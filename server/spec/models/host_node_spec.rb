
describe HostNode do
  before(:all) do
    described_class.create_indexes
  end

  it { should be_timestamped_document }
  it { should be_kind_of(EventStream) }
  it { should have_fields(:node_id, :name, :os, :driver, :public_ip).of_type(String) }
  it { should have_fields(:labels).of_type(Array) }
  it { should have_fields(:mem_total, :mem_limit).of_type(Integer) }
  it { should have_fields(:last_seen_at).of_type(Time) }

  it { should embed_many(:volume_drivers) }
  it { should embed_many(:network_drivers) }
  it { should belong_to(:grid) }
  it { should have_many(:grid_service_instances) }
  it { should have_many(:event_logs) }
  it { should have_many(:containers) }
  it { should have_many(:host_node_stats) }
  it { should have_many(:volume_instances) }

  it { should have_index_for(grid_id: 1) }
  it { should have_index_for(grid_id: 1, node_number: 1).with_options(sparse: true, unique: true) }
  it { should have_index_for(node_id: 1) }


  describe '#connected?' do
    it 'returns true when connected' do
      subject.connected = true
      expect(subject.connected?).to eq(true)
    end

    it 'returns false when not connected' do
      expect(subject.connected?).to eq(false)
    end
  end

  describe '#stateful?' do
    let(:grid) { Grid.create!(name: 'test') }
    let(:stateful_service) {
      GridService.create!(name: 'stateful', image_name: 'foo/bar:latest', grid: grid, stateful: true)
    }
    let(:stateless_service) {
      GridService.create!(name: 'stateless', image_name: 'foo/bar:latest', grid: grid, stateful: false)
    }
    let(:node) { HostNode.create(name: 'node-1', grid: grid)}

    it 'returns false by default' do
      expect(subject.stateful?).to be_falsey
    end

    it 'returns true if node has stateful service' do
      stateful_service.containers.create!(name: 'stateful-1', host_node: node)
      expect(node.stateful?).to be_truthy
    end

    it 'returns false if node has stateless service' do
      stateless_service.containers.create!(name: 'stateless-1', host_node: node)
      expect(node.stateful?).to be_falsey
    end

    it 'returns true if node has stateful and stateless service' do
      stateful_service.containers.create!(name: 'stateful-1', host_node: node)
      stateless_service.containers.create!(name: 'stateless-1', host_node: node)
      expect(node.stateful?).to be_truthy
    end
  end

  describe '#initial_member?' do
    let(:grid) { Grid.create!(name: 'test', initial_size: 1) }
    let(:node_1) { HostNode.create(name: 'node-1', grid: grid, node_number: 1)}
    let(:node_2) { HostNode.create(name: 'node-2', grid: grid, node_number: 2)}

    it 'returns true if initial_member' do
      expect(node_1.initial_member?).to be_truthy
    end

    it 'returns false if not initial_member' do
      expect(node_2.initial_member?).to be_falsey
    end

    it 'returns false if node_number is not set' do
      expect(subject.initial_member?).to be_falsey
    end
  end

  describe '#attributes_from_docker' do
    it 'sets name' do
      expect {
        subject.attributes_from_docker({'Name' => 'node-3'})
      }.to change{ subject.name }.to('node-3')
    end

    it 'does not set name if name is already set' do
      subject.name = 'foobar'
      expect {
        subject.attributes_from_docker({'Name' => 'node-3'})
      }.not_to change{ subject.name }
    end

    it 'sets public_ip' do
      expect {
        subject.attributes_from_docker({'PublicIp' => '127.0.0.1'})
      }.to change{ subject.public_ip }.to('127.0.0.1')
    end

    it 'sets private_ip' do
      expect {
        subject.attributes_from_docker({'PrivateIp' => '192.168.66.2'})
      }.to change{ subject.private_ip }.to('192.168.66.2')
    end

    it 'sets labels' do
      expect {
        subject.attributes_from_docker({'Labels' => ['foo=bar']})
      }.to change{ subject.labels }.to(['foo=bar'])
    end

    it 'does not overwrite existing labels' do
      subject.labels = ['bar=baz']
      expect {
        subject.attributes_from_docker({'Labels' => ['foo=bar']})
      }.not_to change{ subject.labels }
    end

    it 'sets agent_version' do
      expect {
        subject.attributes_from_docker({'AgentVersion' => '1.2.3'})
      }.to change{ subject.agent_version }.to('1.2.3')
    end

    it 'sets volume drivers' do
      subject.attributes_from_docker({'Drivers' => {'Volume' => [
        { 'name' => 'local' }, { 'name' => 'foobar', 'version' => 'latest' }
      ]}})
      expect(subject.volume_drivers.first.name).to eq('local')
      expect(subject.volume_drivers.last.name).to eq('foobar')
      expect(subject.volume_drivers.last.version).to eq('latest')
    end
  end

  describe '#save!' do
    let(:grid) { Grid.create!(name: 'test') }

    it 'reserves node number' do |variable|
      allow(subject).to receive(:grid).and_return(grid)
      subject.attributes = {node_id: 'bb', grid_id: 1}
      subject.save!
      expect(subject.node_number).to eq(1)
    end

    it 'reserves node number successfully after race condition error' do
      HostNode.create!(node_id: 'aa', node_number: 1, grid_id: 1)
      allow(subject).to receive(:grid).and_return(grid)
      subject.attributes = {node_id: 'bb', grid_id: 1}
      subject.save!
      expect(subject.node_number).to eq(2)
    end

    it 'appends node_number to name if name is not unique' do
      grid = Grid.create!(name: 'test')
      HostNode.create!(name: 'node', node_id: 'aa', node_number: 1, grid: grid)

      subject.attributes = {name: 'node', grid: grid}
      subject.save
      expect(subject.name).to eq('node-2')

      subject.name = 'foo'
      subject.save
      expect(subject.name).to eq('foo')
    end

    it 'does not append node_number to name if name is empty' do
      grid = Grid.create!(name: 'test')
      HostNode.create!(node_id: 'aa', node_number: 1, grid: grid)

      subject.attributes = {grid: grid}
      subject.save
      expect(subject.name).to be_nil
    end
  end

  describe '#region' do
    it 'returns default if region is not found from labels' do
      expect(subject.region).to eq('default')
    end

    it 'returns default if labels is nil' do
      allow(subject).to receive(:labels).and_return(nil)
      expect(subject.region).to eq('default')
    end

    it 'returns region from labels' do
      subject.labels = ['foo=bar', 'region=ams2']
      expect(subject.region).to eq('ams2')
    end
  end

  describe '#availability_zone' do
    it 'returns default if az is not found from labels' do
      expect(subject.availability_zone).to eq('default')
    end

    it 'returns default if labels is nil' do
      allow(subject).to receive(:labels).and_return(nil)
      expect(subject.availability_zone).to eq('default')
    end

    it 'returns availability_zone from labels' do
      subject.labels = ['foo=bar', 'az=b']
      expect(subject.availability_zone).to eq('b')
    end
  end

  describe '#host_provider' do
    it 'returns default if provider is not found from labels' do
      expect(subject.host_provider).to eq('default')
    end

    it 'returns default if labels is nil' do
      allow(subject).to receive(:labels).and_return(nil)
      expect(subject.host_provider).to eq('default')
    end

    it 'returns host_provider from labels' do
      subject.labels = ['foo=bar', 'provider=aws']
      expect(subject.host_provider).to eq('aws')
    end
  end

  describe '#ephemeral?' do
    it 'returns false if label is not set' do
      expect(subject).to_not be_ephemeral
    end

    it 'returns true if label is set' do
      subject.labels = ['ephemeral']

      expect(subject).to be_ephemeral
    end

    it 'returns true if label is set with an empty value' do
      subject.labels = ['ephemeral=']

      expect(subject).to be_ephemeral
    end

    it 'returns true if label is set with any value' do
      subject.labels = ['ephemeral=yes']

      expect(subject).to be_ephemeral
    end
  end

  describe '#destroy' do
    let(:grid) { Grid.create!(name: 'test') }
    let(:stateful_service) {
      GridService.create!(name: 'stateful', image_name: 'foo/bar:latest', grid: grid, stateful: true)
    }
    let(:stateless_service) {
      GridService.create!(name: 'stateless', image_name: 'foo/bar:latest', grid: grid, stateful: false)
    }
    let(:node) { HostNode.create(name: 'node-1', grid: grid)}
    let(:another_node) { HostNode.create(name: 'node-1', grid: grid)}

    it 'destroys all containers from a node' do

      stateful_service.containers.create!(
        name: 'redis-1', host_node: node, instance_number: 1
      )
      stateful_service.containers.create!(
        name: 'redis-1-volumes', host_node: node, instance_number: 1, container_type: 'volume'
      )
      stateful_service.containers.create!(
        name: 'redis-2', host_node: another_node, instance_number: 2
      )
      stateful_service.containers.create!(
        name: 'redis-2-volumes', host_node: another_node, instance_number: 2, container_type: 'volume'
      )
      expect {
        node.destroy
      }.to change{Container.unscoped.count}.by (-2)
    end

  end
end

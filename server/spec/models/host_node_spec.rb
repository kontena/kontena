
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
  it { should have_many(:grid_service_instances).with_dependent(:nullify) }
  it { should have_many(:event_logs) }
  it { should have_many(:containers) }
  it { should have_many(:host_node_stats) }
  it { should have_many(:volume_instances) }

  it { should have_index_for(grid_id: 1) }
  it { should have_index_for(grid_id: 1, node_number: 1).with_options(unique: true) }
  it { should have_index_for(grid_id: 1, name: 1).with_options(unique: true) }
  it { should have_index_for(node_id: 1) }
  it { should have_index_for(token: 1).with_options(sparse: true, unique: true) }

  let(:attributes) { { }}
  let(:grid) { Grid.create!(name: 'test', initial_size: 1) }
  subject { HostNode.new(grid: grid, node_number: 1, name: 'node-1', **attributes) }
  let(:node2) { HostNode.create!(grid: grid, name: 'node-2', node_number: 2)}

  describe '#to_s' do
    it "uses the node name" do
      expect(subject.to_s).to eq 'node-1'
    end
  end

  describe '#to_path' do
    it 'uses the node name' do
      expect(subject.to_path).to eq 'test/node-1'
    end
  end

  context 'for a newly created node' do
    it 'is not connected' do
      expect(subject.connected?).to eq(false)
    end
    it 'is not updated' do
      expect(subject.updated?).to eq(false)
    end
    it 'is status=created' do
      expect(subject.status).to eq :created
    end

    describe '#websocket_error' do
      it 'is not connected' do
        expect(subject.websocket_error).to match 'Websocket is not connected'
      end
    end
  end

  context 'when the node exists' do
    before do
      subject.save!
    end

    it 'does not allow duplicate names' do
      expect{HostNode.create!(grid: grid, node_number: 2, name: 'node-1')}.to raise_error(Mongo::Error::OperationFailure, /E11000 duplicate key error index/)
    end

    it 'does not allow duplicate node numbers' do
      expect{HostNode.create!(grid: grid, node_number: 1, name: 'node-2')}.to raise_error(Mongo::Error::OperationFailure, /E11000 duplicate key error index/)
    end
  end

  context 'for an initializing node that has just connected, but is not yet connected or updated' do
    let(:attributes) { {node_id: 'ABC:XYZ', connected: false, updated: false} }

    it 'is status=offline' do
      expect(subject.status).to eq :offline
    end
  end

  context 'for an connecting node that has not yet updated' do
    let(:attributes) { {node_id: 'ABC:XYZ', connected: true, updated: false} }

    it 'is connected' do
      expect(subject.connected?).to eq true
    end

    it 'is status=connecting' do
      expect(subject.status).to eq :connecting
    end

    describe '#websocket_error' do
      it 'is nil' do
        expect(subject.websocket_error).to be nil
      end
    end
  end

  context 'for an connected node that has updated' do
    let(:attributes) { {node_id: 'ABC:XYZ', connected: true, updated: true} }

    it 'is connected' do
      expect(subject.connected?).to eq true
    end

    it 'is status=connected' do
      expect(subject.status).to eq :online
    end
  end

  context 'for a disconnected node' do
    let(:attributes) { {node_id: 'ABC:XYZ', connected: false, updated: true, websocket_connection: { opened: true, close_code: 1337, close_reason: "testing" }} }

    it 'is not connected' do
      expect(subject.connected?).to eq false
    end

    it 'is status=offline' do
      expect(subject.status).to eq :offline
    end

    describe '#websocket_error' do
      it 'was disconnected' do
        expect(subject.websocket_error).to match /Websocket disconnected at .* with code 1337: testing/
      end
    end
  end

  context 'for a rejected node' do
    let(:attributes) { {node_id: 'ABC:XYZ', connected: false, updated: false, websocket_connection: { opened: false, close_code: 1337, close_reason: "testing" }} }

    it 'is not connected' do
      expect(subject.connected?).to eq false
    end

    it 'is status=offline' do
      expect(subject.status).to eq :offline
    end

    describe '#websocket_error' do
      it 'was rejected' do
        expect(subject.websocket_error).to match /Websocket connection rejected at .* with code 1337: testing/
      end
    end
  end

  describe '#stateful?' do
    let(:stateful_service) {
      GridService.create!(name: 'stateful', image_name: 'foo/bar:latest', grid: grid, stateful: true)
    }
    let(:stateless_service) {
      GridService.create!(name: 'stateless', image_name: 'foo/bar:latest', grid: grid, stateful: false)
    }

    it 'returns false by default' do
      expect(subject.stateful?).to be_falsey
    end

    it 'returns true if node has stateful service' do
      stateful_service.containers.create!(name: 'stateful-1', host_node: subject)
      expect(subject.stateful?).to be_truthy
    end

    it 'returns false if node has stateless service' do
      stateless_service.containers.create!(name: 'stateless-1', host_node: subject)
      expect(subject.stateful?).to be_falsey
    end

    it 'returns true if node has stateful and stateless service' do
      stateful_service.containers.create!(name: 'stateful-1', host_node: subject)
      stateless_service.containers.create!(name: 'stateless-1', host_node: subject)
      expect(subject.stateful?).to be_truthy
    end
  end

  describe '#initial_member?' do
    it 'returns true if initial_member' do
      expect(subject.initial_member?).to be_truthy
    end

    it 'returns false if not initial_member' do
      expect(node2.initial_member?).to be_falsey
    end
  end

  describe '#attributes_from_docker' do
    it 'does not set name if name is already set' do
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

    it 'destroys all containers from a node' do
      stateful_service.containers.create!(
        name: 'redis-1', host_node: subject, instance_number: 1
      )
      stateful_service.containers.create!(
        name: 'redis-1-volumes', host_node: subject, instance_number: 1, container_type: 'volume'
      )
      stateful_service.containers.create!(
        name: 'redis-2', host_node: node2, instance_number: 2
      )
      stateful_service.containers.create!(
        name: 'redis-2-volumes', host_node: node2, instance_number: 2, container_type: 'volume'
      )
      expect {
        subject.destroy
      }.to change{Container.unscoped.count}.by (-2)
    end

  end

  describe '#volume_driver' do
    let(:grid) { Grid.create!(name: 'test') }

    it 'returns correct volume driver' do
      subject.save!
      subject.volume_drivers.create!(name: 'foo', version: '1')

      driver = subject.volume_driver('foo')
      expect(driver['name']).to eq('foo')
      expect(driver['version']).to eq('1')
    end

    it 'returns nil for unknown driver' do
      driver = subject.volume_driver('foo')
      expect(driver).to be_nil
    end
  end

  it 'does not allow an empty name' do
    expect{HostNode.create!(grid: grid, name: '')}.to raise_error(Mongoid::Errors::Validations, /Name can't be blank/)
  end

  describe '#token' do
    let(:grid) { Grid.create!(name: 'test') }

    it 'allows multiple nodes without node tokens' do
      node1 = HostNode.create!(grid: grid, name: 'node-1', node_number: 1)
      node2 = HostNode.create!(grid: grid, name: 'node-2', node_number: 2)

      expect(node1.token).to be_nil
      expect(node2.token).to be_nil
    end

    it 'does not allow empty tokens' do
      expect{HostNode.create!(grid: grid, name: 'node-1', node_number: 1, token: '')}.to raise_error(Mongoid::Errors::Validations)
    end

    context 'with a node that has a node token' do
      let(:token) { 'asdf'* 4 }
      let(:node1) { HostNode.create!(grid: grid, name: 'node-1', node_number: 1, token: token) }

      before do
        node1
      end

      it 'has a node token' do
        expect(node1.token).to eq 'asdfasdfasdfasdf'

        expect(HostNode.find_by(token: token).id).to eq node1.id
      end

      it 'does not allow multiple nodes to share the same token' do
        expect{HostNode.create!(grid: grid, name: 'node-2', node_number: 2, token: token)}.to raise_error(Mongo::Error::OperationFailure, /E11000 duplicate key error index: kontena_test.host_nodes.\$token_1 dup key: { : "asdfasdfasdfasdf" }/)
      end

      context 'with a second grid' do
        let(:grid2) { Grid.create!(name: 'test2') }

        it 'does not allow nodes to share the same token' do
          expect{HostNode.create!(grid: grid2, name: 'node-2', node_number: 2, token: token)}.to raise_error(Mongo::Error::OperationFailure, /E11000 duplicate key error index: kontena_test.host_nodes.\$token_1 dup key: { : "asdfasdfasdfasdf" }/)
        end
      end
    end
  end
end

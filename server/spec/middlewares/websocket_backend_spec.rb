require_relative '../../app/middlewares/websocket_backend'

describe WebsocketBackend, celluloid: true, eventmachine: true do
  let(:app) { spy(:app) }
  let(:subject) { described_class.new(app) }

  let(:logger) { instance_double(Logger) }
  before do
    allow(subject).to receive(:logger).and_return(logger)
    allow(logger).to receive(:debug)
  end

  before(:each) do
    stub_const('Server::VERSION', '0.9.1')
  end

  after(:each) do
    subject.stop_rpc_server
  end

  describe '#our_version' do
    it 'retuns baseline version with patch level 0' do
      expect(subject.our_version).to eq('0.9.0')
    end
  end

  describe '#valid_agent_version?' do
    it 'returns true when exact match' do
      expect(subject.valid_agent_version?('0.9.1')).to eq(true)
    end

    it 'returns true when exact match with beta' do
      stub_const('Server::VERSION', '0.9.0.beta')
      expect(subject.valid_agent_version?('0.9.0.beta')).to eq(true)
    end

    it 'returns true when patch level is greater' do
      expect(subject.valid_agent_version?('0.9.2')).to eq(true)
    end

    it 'returns true when patch level is less than' do
      expect(subject.valid_agent_version?('0.9.0')).to eq(true)
    end

    it 'returns false when minor version is different' do
      expect(subject.valid_agent_version?('0.8.4')).to eq(false)
    end

    it 'returns false when major version is different' do
      expect(subject.valid_agent_version?('1.0.1')).to eq(false)
    end
  end

  describe '#subscribe_to_rpc_channel' do
    let(:client) do
      {
          ws: spy(:ws)
      }
    end

    it 'sends message if client is found' do
      allow(subject).to receive(:client_for_id).and_return(client)
      expect(subject).to receive(:send_message).with(client[:ws], 'hello')
      MongoPubsub.publish('rpc_client', {type: 'request', message: 'hello'})
      sleep 0.05
      EM.run_deferred_callbacks
    end

    it 'does not send message if client is not found' do
      expect(subject).not_to receive(:send_message).with(client[:ws], 'hello')
      MongoPubsub.publish('rpc_client', {type: 'request', message: 'hello'})
      sleep 0.05
    end
  end

  context "for a connecting client" do
    let(:grid) do
      Grid.create!(name: 'test', token: 'secret123')
    end

    let(:grid_token) { 'secret123' }
    let(:node_id) { 'nodeABC' }
    let(:node_labels) { 'test1,test2' }
    let(:node_version) { '0.9.1' }
    let(:connected_at) { 1.second.ago.utc }

    let(:client_ws) { instance_double(Faye::WebSocket) }
    let(:rack_req) { instance_double(Rack::Request, env: {
      'HTTP_KONTENA_GRID_TOKEN' => grid_token,
      'HTTP_KONTENA_NODE_ID' => node_id,
      'HTTP_KONTENA_NODE_LABELS' => node_labels,
      'HTTP_KONTENA_VERSION' => node_version,
      'HTTP_KONTENA_CONNECTED_AT' => connected_at.strftime('%F %T.%NZ'),
    })}

    before do
      grid
    end

    context "without any grid token" do
      let(:rack_req) { instance_double(Rack::Request, env: {})}

      describe '#on_open' do
        it 'closes the connection without creating the node' do
          expect(subject.logger).to receive(:error).with('invalid grid token, closing connection')
          expect(client_ws).to receive(:close).with(4001, 'Invalid grid token')

          expect{
            subject.on_open(client_ws, rack_req)
          }.to not_change{grid.reload.host_nodes}
        end
      end
    end

    context "with the wrong grid token" do
      let(:grid_token) { 'the wrong secret' }

      describe '#on_open' do
        it 'closes the connection without creating the node' do
          expect(subject.logger).to receive(:error).with('invalid grid token, closing connection')
          expect(client_ws).to receive(:close).with(4001, 'Invalid grid token')

          expect{
            subject.on_open(client_ws, rack_req)
          }.to not_change{grid.reload.host_nodes}
        end
      end
    end

    describe '#on_open' do
      it 'accepts the connection and creates a new host node' do
        expect(subject.logger).to receive(:info).with(/node nodeABC agent version 0.9.1 connected at #{connected_at}, \d+\.\d+s ago/)

        allow(EM).to receive(:defer) do |&block|
          block.call
        end
        expect(subject).to receive(:send_message).with(client_ws, [2, '/agent/master_info', [{ 'version' => '0.9.1'}]])
        expect(subject).to receive(:send_message).with(client_ws, [2, '/agent/node_info', [hash_including('id' => 'nodeABC')]])

        expect{
          subject.on_open(client_ws, rack_req)
        }.to change{grid.reload.host_nodes.count}.from(0).to(1)

        host_node = grid.host_nodes.first

        expect(host_node.node_id).to eq node_id
        expect(host_node.connected).to eq true
        expect(host_node.connected_at.to_s).to eq connected_at.to_datetime.to_s
      end
    end
  end

  context "with a connected client" do
    let(:client_ws) { instance_double(Faye::WebSocket) }
    let(:connected_at) { 1.minute.ago }
    let(:client) do
      { id: 'aa', ws: client_ws, connected_at: connected_at }
    end

    let(:grid) do
      Grid.create!(name: 'test')
    end

    let(:node) do
      HostNode.create!(name: 'test-node', node_id: 'aa', grid: grid,
        connected: true, connected_at: connected_at,
      )
    end

    before do
      subject.instance_variable_get('@clients') << client
    end

    describe '#on_close' do
      it "logs a warning if the client is not found" do
        subject.instance_variable_get('@clients').clear

        expect(subject.logger).to receive(:debug).with('ignore close of unplugged client')

        subject.on_close(client_ws)
      end

      it "calls unplug_client" do
        expect(subject.logger).to receive(:info).with('node aa connection closed')

        expect(subject).to receive(:unplug_client).with(client)

        subject.on_close(client_ws)
      end

      it "rescues errors" do
        expect(subject).to receive(:unplug_client).and_raise("failed")

        expect(subject.logger).to receive(:info).with('node aa connection closed')
        expect(subject.logger).to receive(:error).with('on_close: failed')
        expect(subject.logger).to receive(:error)

        subject.on_close(client_ws)
      end
    end

    describe '#unplug_client' do
      it "logs a warning if the host node is not found" do
        node.set(node_id: 'bb')

        expect(subject.logger).to receive(:warn).with('skip unplug of missing node aa')

        subject.unplug_client(client)
      end

      it "does not disconnect the node if another connection is active" do
        node.set(connected_at: Time.now)

        expect {
          subject.unplug_client(client)
        }.to not_change{node.reload; [node.connected, node.connected_at]}
      end

      it "disconnects the node" do
        expect {
          subject.unplug_client(client)
        }.to change{node.reload.connected}.to be_falsey
      end
    end

    describe '#on_client_timeout' do
      it 'closes the connection and unplugs the client' do
        expect(subject.logger).to receive(:warn).with(/Close node aa connection after \d+\.\d+s timeout/)

        expect(client_ws).to receive(:close).with(4030, /ping timeout after \d+\.\d+s/)
        expect(subject).to receive(:unplug_client).with(client)

        subject.on_client_timeout(client, 0.1)
      end
    end

    describe '#on_pong' do
      it 'closes the websocket if client is not found' do
        client[:id] = 'bb'
        expect(subject.logger).to receive(:warn).with('Close connection of removed node bb')
        expect(client_ws).to receive(:close).with(4040, 'host node bb has been removed')
        expect(subject).to receive(:unplug_client).with(client)

        subject.on_pong(client, 0.1)
      end

      it 'closes connection if node is not marked as connected' do
        node.set(connected: false)
        expect(subject.logger).to receive(:warn).with('Close connection of disconnected node test-node')
        expect(client_ws).to receive(:close).with(4042, 'host node test-node has been disconnected')
        expect(subject).to receive(:unplug_client).with(client)

        subject.on_pong(client, 0.1)
      end

      it 'updates node last_seen_at if node is marked as connected' do
        expect(subject.logger).to_not receive(:warn)

        node.set(connected: true)
        expect(client_ws).not_to receive(:close)

        expect {
          subject.on_pong(client, 0.1)
        }.to change { node.reload.last_seen_at }
      end

      it 'logs a warning if ping delay is over threshold' do
        node.set(connected: true)

        expect(subject.logger).to receive(:warn).with('keepalive ping 3.00s of 5.00s timeout from client aa')
        expect(client_ws).not_to receive(:close)

        subject.on_pong(client, 3.0)
      end
    end
  end
end

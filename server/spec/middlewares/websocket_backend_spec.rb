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

    let(:grid_token) { nil }
    let(:node_token) { nil }
    let(:node_id) { 'nodeABC' }
    let(:node_name) { 'node-1' }
    let(:node_labels) { 'test=yes' }
    let(:node_version) { '0.9.1' }
    let(:connected_at) { 1.second.ago.utc }

    let(:client_ws) { instance_double(Faye::WebSocket) }
    let(:rack_req) { instance_double(Rack::Request, env: {
      'HTTP_KONTENA_GRID_TOKEN' => grid_token,
      'HTTP_KONTENA_NODE_TOKEN' => node_token,
      'HTTP_KONTENA_NODE_ID' => node_id,
      'HTTP_KONTENA_NODE_NAME' => node_name,
      'HTTP_KONTENA_NODE_LABELS' => node_labels,
      'HTTP_KONTENA_VERSION' => node_version,
      'HTTP_KONTENA_CONNECTED_AT' => connected_at ? connected_at.strftime('%F %T.%NZ') : nil,
    }.compact)}

    before do
      grid

      # block weird errors from unexpected send_message -> ws.send
      expect(client_ws).to_not receive(:send)
    end

    context "without any token" do
      let(:rack_req) { instance_double(Rack::Request, env: {
        'HTTP_KONTENA_NODE_ID' => node_id,
        'HTTP_KONTENA_NODE_NAME' => node_name,
        'HTTP_KONTENA_VERSION' => node_version,
      })}

      describe '#on_open' do
        it 'closes the connection without creating the node' do
          expect(subject).not_to receive(:send_master_info).with(client_ws)
          expect(subject.logger).to receive(:warn).with('reject websocket connection for node nodeABC: Missing token')
          expect(client_ws).to receive(:close).with(4004, 'Missing token')

          expect{
            subject.on_open(client_ws, rack_req)
          }.to not_change{grid.reload.host_nodes}
        end
      end
    end

    context "without a node ID" do
      let(:node_id) { nil }

      describe '#on_open' do
        it 'closes the connection without creating the node' do
          expect(subject.logger).to receive(:warn).with('reject websocket connection for node <nil>: Missing Kontena-Node-ID')
          expect(client_ws).to receive(:close).with(4000, 'Missing Kontena-Node-ID')

          expect{
            subject.on_open(client_ws, rack_req)
          }.to not_change{grid.reload.host_nodes}
        end
      end
    end

    context "with an empty node ID" do
      let(:node_id) { "" }

      describe '#on_open' do
        it 'closes the connection without creating the node' do
          expect(subject.logger).to receive(:warn).with('reject websocket connection for node : Missing Kontena-Node-ID')
          expect(client_ws).to receive(:close).with(4000, 'Missing Kontena-Node-ID')

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
          expect(subject).not_to receive(:send_master_info).with(client_ws)
          expect(subject.logger).to receive(:warn).with('reject websocket connection for node nodeABC: Invalid grid token')
          expect(client_ws).to receive(:close).with(4001, 'Invalid grid token')

          expect{
            subject.on_open(client_ws, rack_req)
          }.to not_change{grid.reload.host_nodes}
        end
      end
    end

    context "with a grid token and node ID that has a node token " do
      let(:host_node) { grid.create_node!('node-1', node_id: 'nodeABC', token: 'asdfasdfasdfasdf') }

      let(:grid_token) { 'secret123' }
      let(:node_token) { nil }

      before do
        host_node
      end

      describe '#on_open' do
        it 'closes the connection without connecting the node' do
          expect(subject.logger).to receive(:warn).with('reject websocket connection for node nodeABC: Invalid grid token, node was created using a node token')
          expect(client_ws).to receive(:close).with(4005, 'Invalid grid token, node was created using a node token')

          expect{
            subject.on_open(client_ws, rack_req)
          }.to not_change{host_node.reload}
        end
      end
    end

    context "with the wrong node token" do
      let(:host_node) { grid.create_node!('node-1', token: 'asdfasdfasdfasdf') }

      let(:grid_token) { nil }
      let(:node_token) { 'the wrong secret' }

      before do
        host_node
      end

      describe '#on_open' do
        it 'closes the connection without connecting the node' do
          expect(subject).not_to receive(:send_master_info).with(client_ws)
          expect(subject.logger).to receive(:warn).with('reject websocket connection for node nodeABC: Invalid node token')
          expect(client_ws).to receive(:close).with(4002, 'Invalid node token')

          expect{
            subject.on_open(client_ws, rack_req)
          }.to not_change{host_node.reload}
        end
      end
    end

    context "with the wrong node ID" do
      let(:host_node) { grid.create_node!('node-1', token: 'asdfasdfasdfasdf', node_id: 'nodeABC') }

      let(:grid_token) { nil }
      let(:node_token) { 'asdfasdfasdfasdf' }
      let(:node_id) { 'nodeXYZ' }

      before do
        host_node
      end

      describe '#on_open' do
        it 'closes the connection without connecting the node' do
          expect(subject.logger).to receive(:warn).with('new node node-1 connected using node token with node_id nodeXYZ, but the node token was already used by node-1 with node ID nodeABC')
          expect(subject).not_to receive(:send_master_info).with(client_ws)
          expect(subject.logger).to receive(:warn).with('reject websocket connection for node nodeXYZ: Invalid node token, already used by a different node')
          expect(client_ws).to receive(:close).with(4003, 'Invalid node token, already used by a different node')

          expect{
            subject.on_open(client_ws, rack_req)
          }.to not_change{host_node.reload}
        end
      end
    end

    context "with a duplicate node ID" do
      let(:host_node1) { grid.create_node!('node-1', token: 'asdfasdfasdfasdf1', node_id: 'nodeABC') }
      let(:host_node2) { grid.create_node!('node-2', token: 'asdfasdfasdfasdf2') }

      let(:grid_token) { nil }
      let(:node_token) { 'asdfasdfasdfasdf2' }
      let(:node_id) { 'nodeABC' }

      before do
        host_node1
        host_node2
      end

      describe '#on_open' do
        it 'closes the connection without connecting the node' do
          expect(subject.logger).to receive(:warn).with('node node-2 connected using node token with node_id nodeABC, but that node ID already exists for node-1')
          expect(subject.logger).to receive(:warn).with('reject websocket connection for node nodeABC: Invalid node ID, already used by a different node')
          expect(client_ws).to receive(:close).with(4006, 'Invalid node ID, already used by a different node')

          expect{
            subject.on_open(client_ws, rack_req)
          }.to not_change{host_node1.reload}.and not_change{host_node2.reload}
        end
      end
    end

    context "with the wrong version" do
      let(:grid_token) { 'secret123' }
      let(:node_version) { '0.8.0' }
      let(:connected_at) { nil }

      describe '#on_open' do
        it 'creates the node, but does not connect it' do
          #expect(subject.logger).to receive(:info).with('new node node-1 connected using grid token')
          expect(subject).to receive(:send_master_info).with(client_ws)
          expect(subject.logger).to receive(:warn).with('reject websocket connection for node nodeABC: agent version 0.8.0 is not compatible with server version 0.9.1')
          expect(client_ws).to receive(:close).with(4010, 'agent version 0.8.0 is not compatible with server version 0.9.1')

          subject.on_open(client_ws, rack_req)

        end
      end
    end

    context "with a Kontena-Connected-At time in the past" do
      let(:grid_token) { 'secret123' }
      let(:connected_at) { 5.minutes.ago.utc }

      describe '#on_open' do
        it 'creates the node, but does not connect it' do
          expect(subject.logger).to receive(:info).with('new node node-1 connected using grid token')
          expect(subject).to_not receive(:send_master_info).with(client_ws)
          expect(subject.logger).to receive(:warn).with(/reject websocket connection for node node-1: agent connected too far in the past, clock offset \d+\.\d+s exceeds threshold/)
          expect(client_ws).to receive(:close).with(4020, /agent connected too far in the past, clock offset \d+\.\d+s exceeds threshold/)

          expect{
            subject.on_open(client_ws, rack_req)
          }.to change{grid.host_nodes.find_by(node_id: node_id)}.from(nil).to(HostNode)

          host_node = grid.host_nodes.first

          expect(host_node.node_id).to eq node_id
          expect(host_node.connected).to eq false
          expect(host_node.connected_at).to be < Time.now.utc
          expect(host_node.status).to eq :offline
          expect(host_node.websocket_error).to match /Websocket connection rejected at .* with code 4020: agent connected too far in the past,.*/
        end
      end
    end

    context "with a Kontena-Connected-At time in the future" do
      let(:grid_token) { 'secret123' }
      let(:connected_at) { Time.now.utc + 60.0 }

      describe '#on_open' do
        it 'creates the node, but does not connect it' do
          expect(subject.logger).to receive(:info).with('new node node-1 connected using grid token')
          expect(subject).to_not receive(:send_master_info).with(client_ws)
          expect(subject.logger).to receive(:warn).with(/reject websocket connection for node node-1: agent connected too far in the future, clock offset -\d+\.\d+s exceeds threshold/)
          expect(client_ws).to receive(:close).with(4020, /agent connected too far in the future, clock offset -\d+\.\d+s exceeds threshold/)

          expect{
            subject.on_open(client_ws, rack_req)
          }.to change{grid.host_nodes.find_by(node_id: node_id)}.from(nil).to(HostNode)

          host_node = grid.host_nodes.first

          expect(host_node.node_id).to eq node_id
          expect(host_node.connected).to eq false
          expect(host_node.connected_at).to be < Time.now.utc
          expect(host_node.status).to eq :offline
          expect(host_node.websocket_error).to match /Websocket connection rejected at .* with code 4020: agent connected too far in the future, .*/
        end
      end
    end

    describe '#on_open' do
      context 'with a valid grid token' do
        let(:grid_token) { 'secret123' }

        before do
          # force sync plugin
          allow(EM).to receive(:defer) do |&block|
            block.call
          end
        end

        it 'accepts the connection and creates a new host node' do
          expect(subject.logger).to receive(:info).with('new node node-1 connected using grid token')
          expect(subject).to receive(:send_master_info).with(client_ws)
          expect(subject.logger).to receive(:info).with(/node node-1 agent version 0.9.1 connected at #{connected_at}, \d+\.\d+s ago/)

          expect{
            subject.on_open(client_ws, rack_req)
          }.to change{grid.reload.host_nodes.count}.from(0).to(1)

          host_node = grid.host_nodes.first

          expect(host_node.node_id).to eq 'nodeABC'
          expect(host_node.name).to eq 'node-1'
          expect(host_node.labels).to eq ['test=yes']
          expect(host_node.agent_version).to eq '0.9.1'
          expect(host_node.connected).to eq true
          expect(host_node.connected_at.to_s).to eq connected_at.to_s

          # XXX: racy via mongo pubsub
          expect(subject).to receive(:send_message).with(client_ws, [2, '/agent/node_info', [hash_including('id' => 'nodeABC', 'name' => 'node-1')]])

          sleep 0.1
          EM.run_deferred_callbacks
        end

        context "with a duplicate node name" do
          let(:host_node1) { grid.create_node!('node-1', node_id: 'nodeXYZ') }

          before do
            host_node1
          end

          describe '#on_open' do
            it 'creates the node with a suffixed name' do
              host_node = nil

              expect(subject.logger).to receive(:info).with('new node node-1-2 connected using grid token')
              expect(subject).to receive(:send_master_info).with(client_ws)
              expect(subject.logger).to receive(:info)

              expect{
                subject.on_open(client_ws, rack_req)
              }.to change{host_node = grid.host_nodes.find_by(node_id: node_id)}.from(nil).to(HostNode)

              expect(host_node.node_id).to eq node_id
              expect(host_node.node_number).to eq 2
              expect(host_node.name).to eq 'node-1-2'

              # XXX: racy via mongo pubsub
              expect(subject).to receive(:send_message).with(client_ws, [2, '/agent/node_info', [hash_including('id' => 'nodeABC', 'name' => 'node-1-2')]])

              sleep 0.1
              EM.run_deferred_callbacks
            end
          end
        end
      end

      context 'with a valid node token' do
        let(:host_node) { grid.create_node!('test-1', token: 'asdfasdfasdfasdf') }

        let(:grid_token) { nil }
        let(:node_token) { 'asdfasdfasdfasdf' }

        before do
          host_node
        end

        it 'accepts the connection and sets the node ID' do
          expect(host_node.status).to eq :created

          expect(subject.logger).to receive(:info).with('new node test-1 connected using node token with node_id nodeABC')
          expect(subject).to receive(:send_master_info).with(client_ws)
          expect(subject.logger).to receive(:info).with(/node test-1 agent version 0.9.1 connected at #{connected_at}, \d+\.\d+s ago/)

          # sync defer { NodePlugger#plugin! }
          allow(EM).to receive(:defer) do |&block|
            host_node.reload # after #find_node_by_node_token

            expect(host_node.connected).to eq false
            expect(host_node.updated).to eq false
            expect(host_node.status).to eq :offline

            block.call

            host_node.reload # after NodePlugger#plugin!

            expect(host_node.connected).to eq true
            expect(host_node.updated).to eq false
            expect(host_node.status).to eq :connecting
          end

          expect{
            subject.on_open(client_ws, rack_req)
          }.to_not change{grid.reload.host_nodes.count}

          host_node.reload

          expect(host_node.node_id).to eq node_id
          expect(host_node.name).to eq 'test-1' # the agent-provided Kontena-Node-Name: node-1 header is ignored
          expect(host_node.labels).to eq ['test=yes']
          expect(host_node.agent_version).to eq '0.9.1'
          expect(host_node.connected).to eq true
          expect(host_node.connected_at.to_s).to eq connected_at.to_s
          expect(host_node.updated).to eq false
          expect(host_node.status).to eq :connecting

          client = subject.client_for_id(node_id)

          expect(client).to_not be_nil
          expect(client).to match({
            ws: client_ws,
            id: node_id,
            node_id: host_node.id,
            grid_id: grid.id,
            created_at: Time,
            connected_at: Time,
          })

          # XXX: racy via mongo pubsub
          expect(subject).to receive(:send_message).with(client_ws, [2, '/agent/node_info', [hash_including('id' => 'nodeABC', 'name' => 'test-1')]])

          sleep 0.1
          EM.run_deferred_callbacks
        end

        it 'accepts the connection if the node ID matches' do
          host_node.set(node_id: node_id, labels: ['test=yes', 'test2=no'])

          expect(subject).to receive(:send_master_info).with(client_ws)
          expect(subject.logger).to receive(:info).with(/node test-1 agent version 0.9.1 connected at #{connected_at}, \d+\.\d+s ago/)

          # sync defer { NodePlugger#plugin! }
          allow(EM).to receive(:defer) do |&block|
            block.call
          end

          expect{
            subject.on_open(client_ws, rack_req)
          }.to not_change{grid.reload.host_nodes.count}.and not_change{host_node.reload.node_id}

          host_node.reload

          expect(host_node.labels).to eq ['test=yes', 'test2=no'] # do not replace existing labels
          expect(host_node.connected).to eq true
          expect(host_node.connected_at.to_s).to eq connected_at.to_s

          client = subject.client_for_id(node_id)

          expect(client).to_not be_nil
          expect(client).to match({
            ws: client_ws,
            id: node_id,
            node_id: host_node.id,
            grid_id: grid.id,
            created_at: Time,
            connected_at: Time,
          })

          # XXX: racy via mongo pubsub
          expect(subject).to receive(:send_message).with(client_ws, [2, '/agent/node_info', [hash_including('id' => 'nodeABC', 'name' => 'test-1')]])

          sleep 0.1
          EM.run_deferred_callbacks
        end
      end
    end
  end

  context "with a connected client" do
    let(:client_ws) { instance_double(Faye::WebSocket) }
    let(:connected_at) { 1.minute.ago }

    let(:grid) do
      Grid.create!(name: 'test')
    end

    let(:node) do
      grid.create_node!('test-node', node_id: 'aa',
        connected: true, connected_at: connected_at,
      )
    end

    let(:client) do
      {
        ws: client_ws,
        id: 'aa',
        node_id: node.id,
        grid_id: grid.id,
        connected_at: connected_at,
       }
    end

    before do
      subject.instance_variable_get('@clients') << client
    end

    describe '#send_master_info' do
      it "sends version" do
        expect(subject).to receive(:send_message).with(client_ws, [2, '/agent/master_info', [{ 'version' => '0.9.1'}]])
        subject.send_master_info(client_ws)
      end
    end

    describe '#on_close' do
      it "logs a warning if the client is not found" do
        subject.instance_variable_get('@clients').clear

        expect(subject.logger).to receive(:debug).with('ignore close of unplugged client with code 1006: asdf')

        subject.on_close(client_ws, 1006, "asdf")
      end

      it "calls unplug_client" do
        expect(subject.logger).to receive(:info).with('node aa connection closed with code 1006: asdf')

        expect(subject).to receive(:unplug_client).with(client, 1006, "asdf")

        subject.on_close(client_ws, 1006, "asdf")
      end

      it "rescues errors" do
        expect(subject).to receive(:unplug_client).with(client, 1006, "asdf").and_raise("failed")

        expect(subject.logger).to receive(:info).with('node aa connection closed with code 1006: asdf')
        expect(subject.logger).to receive(:error).with(RuntimeError)

        subject.on_close(client_ws, 1006, "asdf")
      end
    end

    describe '#unplug_client' do
      it "logs a warning if the host node is missing" do
        node.delete

        expect(subject.logger).to receive(:warn).with('skip unplug of missing node aa')

        subject.unplug_client(client, 1006, "asdf")
      end

      it "does not disconnect the node if another connection is active" do
        node.set(connected_at: Time.now)

        expect {
          subject.unplug_client(client, 1006, "asdf")
        }.to not_change{node.reload; [node.connected, node.connected_at]}
      end

      it "disconnects the node" do
        expect {
          subject.unplug_client(client, 1006, "asdf")
        }.to change{node.reload.connected}.to be_falsey
      end
    end

    describe '#on_client_timeout' do
      it 'closes the connection and unplugs the client' do
        expect(subject.logger).to receive(:warn).with(/Close node aa connection after \d+\.\d+s timeout/)

        expect(client_ws).to receive(:close).with(4030, /ping timeout after \d+\.\d+s/)
        expect(subject).to receive(:unplug_client).with(client, 4030, String)

        subject.on_client_timeout(client, 0.1)
      end
    end

    describe '#on_pong' do
      it 'closes the websocket if node is missing' do
        node.delete

        expect(subject.logger).to receive(:warn).with('Close connection of removed node aa')
        expect(client_ws).to receive(:close).with(4040, 'host node aa has been removed')
        expect(subject).to receive(:unplug_client).with(client, 4040, String)

        subject.on_pong(client, 0.1)
      end

      it 'closes connection if node is not marked as connected' do
        node.set(connected: false)
        expect(subject.logger).to receive(:warn).with('Close connection of disconnected node test-node')
        expect(client_ws).to receive(:close).with(4031, 'host node test-node has been disconnected')
        expect(subject).to receive(:unplug_client).with(client, 4031, String)

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

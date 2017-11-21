describe Kontena::WebsocketClient, :celluloid => true do
  let(:url) { 'ws://socket.example.com' }
  let(:node_id) { 'ABCD' }
  let(:node_name) { 'test-1' }
  let(:grid_token) { 'secret' }
  let(:node_token) { nil }
  let(:node_labels) { ['region=test'] }
  let(:ssl_params) { {} }
  let(:options) {  {} }

  let(:node_id) { 'ABCD' }
  let(:labels) { ['region=test'] }

  before do
    allow_any_instance_of(described_class).to receive(:host_id).and_return(node_id)
    allow_any_instance_of(described_class).to receive(:labels).and_return(labels)
  end

  let(:actor) {
    described_class.new(url, node_id,
      node_name: node_name,
      grid_token: grid_token,
      node_token: node_token,
      node_labels: node_labels,
      ssl_params: ssl_params,
      autostart: false,
      **options
    )
  }
  subject { actor.wrapped_object }
  let(:async) { instance_double(described_class) }

  before do
    allow(subject).to receive(:async).and_return(async)
    allow(actor).to receive(:async).and_return(async)
  end

  describe '#initialize' do
    it 'is not connected' do
      expect(subject.connected?).to be false
    end
  end

  describe '#start' do
    before do
      # run timers immediately, once
      allow(subject.wrapped_object).to receive(:after) do |&block|
        block.call
      end
    end

    it 'connects' do
      expect(subject).to receive(:connect!)

      actor.start
    end
  end

  describe '#connect' do
    it 'creates a websocket client and calls run_websocket' do
      expect(async).to receive(:connect_client)
      expect(subject).to receive(:publish).with('websocket:connect', nil)

      actor.connect!

      expect(subject).to_not be_connected
      expect(subject.ws).to be_a Kontena::Websocket::Client
      expect(subject.ws.url).to eq 'ws://socket.example.com'
      expect(subject.ws.ssl?).to be false
      expect(subject.ws.ssl_verify?).to be false
      expect(subject.ws.instance_variable_get('@headers')).to match(
        'Kontena-Grid-Token' => 'secret',
        'Kontena-Node-Id' => 'ABCD',
        'Kontena-Node-Name' => 'test-1',
        'Kontena-Version' => Kontena::Agent::VERSION,
        'Kontena-Node-Labels' => 'region=test',
        'Kontena-Connected-At' => String,
      )
    end

    context 'with a node token' do
      let(:grid_token) { nil }
      let(:node_token) { 'node-secret' }
      it 'creates a websocket client with Kontena-Node-Token header' do
        expect(async).to receive(:connect_client)

        actor.connect!

        expect(subject).to_not be_connected
        expect(subject.ws).to be_a Kontena::Websocket::Client
        expect(subject.ws.url).to eq 'ws://socket.example.com'
        expect(subject.ws.ssl?).to be false
        expect(subject.ws.ssl_verify?).to be false
        expect(subject.ws.instance_variable_get('@headers')).to match(
          'Kontena-Node-Token' => 'node-secret',
          'Kontena-Node-Id' => 'ABCD',
          'Kontena-Node-Name' => 'test-1',
          'Kontena-Version' => Kontena::Agent::VERSION,
          'Kontena-Node-Labels' => 'region=test',
          'Kontena-Connected-At' => String,
        )
      end
    end
  end

  describe '#ws' do
    it 'fails when not connected' do
      expect{subject.ws}.to raise_error(RuntimeError, "not connected")
    end
  end

  describe '#send_message' do
    it 'fails when not connected' do
      expect{actor.send_message('asdf')}.to raise_error(RuntimeError, "not connected")
    end
  end
  describe '#send_notification' do
    it 'fails when not connected' do
      expect{actor.send_notification('/test', [])}.to raise_error(RuntimeError, "not connected")
    end
  end
  describe '#send_request' do
    it 'fails when not connected' do
      expect{actor.send_request(1, '/test', [])}.to raise_error(RuntimeError, "not connected")
    end
  end

  describe '#disconnect' do
    it 'does nothing if not connected' do
      expect(subject).to receive(:debug).with('close: not connected')

      actor.close!
    end
  end

  context 'with an invalid URL' do
    let(:url) { 'http://api.example.com' }

    describe '#connect' do
      it 'logs error and reconnects' do
        expect(subject).to receive(:error).with(ArgumentError) do |err|
          expect(err.message).to eq 'Invalid websocket URL: http://api.example.com'
        end
        expect(subject).to receive(:reconnect!)

        actor.connect!
      end
    end
  end

  context 'for a wss:// URL with defaults' do
    let(:url) { 'wss://socket.example.com' }

    describe '#connect' do
      it 'creates a websocket client with ssl, and ssl_verify' do
        expect(async).to receive(:connect_client)

        actor.connect!

        expect(subject.ws).to be_a Kontena::Websocket::Client
        expect(subject.ws.url).to eq 'wss://socket.example.com'
        expect(subject.ws.ssl?).to be true
        expect(subject.ws.ssl_verify?).to be true
      end
    end
  end

  context 'for a wss:// URL without ssl verify' do
    let(:url) { 'wss://socket.example.com' }
    let(:ssl_params) { { verify_mode: OpenSSL::SSL::VERIFY_NONE }}

    describe '#connect' do
      it 'creates a websocket client with ssl and no ssl_verify' do
        expect(async).to receive(:connect_client)

        actor.connect!

        expect(subject.ws).to be_a Kontena::Websocket::Client
        expect(subject.ws.url).to eq 'wss://socket.example.com'
        expect(subject.ws.ssl?).to be true
        expect(subject.ws.ssl_verify?).to be false
      end
    end
  end

  context 'for a wss:// URL with ssl_hostname' do
    let(:url) { 'wss://socket.example.com' }
    let(:options) { { ssl_hostname: 'test'} }

    describe '#connect!' do
      it 'creates a websocket client with ssl and ssl_hostname' do
        expect(async).to receive(:connect_client)

        actor.connect!

        expect(subject.ws).to be_a Kontena::Websocket::Client
        expect(subject.ws.url).to eq 'wss://socket.example.com'
        expect(subject.ws.ssl?).to be true
        expect(subject.ws.ssl_hostname).to eq 'test'
        expect(subject.ws.ssl_verify?).to be true
      end
    end
  end

  context 'for a connecting websocket client' do
    let(:ws_client) { instance_double(Kontena::Websocket::Client) }

    before do
      subject.instance_variable_set('@ws', ws_client)
    end
    after do
      # disable finalizer, or it will touch the rspec double outside of the test lifecycle
      subject.instance_variable_set('@ws', nil)
    end

    it 'is not connected' do
      expect(subject.connected?).to be false
    end

    describe '#connect_client' do
      before do
        allow(ws_client).to receive(:on_pong) do |&block|
          @on_pong = block
        end
      end

      it 'runs the websocket client in a separate thread, and reconnects after it returns' do
        expect(ws_client).to receive(:connect) do
          expect(Celluloid.actor?).to be false
        end
        expect(subject).to receive(:on_open) do
          expect(Celluloid.actor?).to be true
          expect(Celluloid.current_actor).to eq actor
        end

        expect(ws_client).to receive(:read) do |&block|
          expect(subject).to receive(:on_message).with('test')

          block.call 'test'

          allow(ws_client).to receive(:close_code).and_return(1000)
          allow(ws_client).to receive(:close_reason).and_return ''
        end
        expect(subject).to_not receive(:on_error)
        expect(subject).to receive(:disconnected!).and_call_original
        expect(subject).to receive(:reconnect!)
        expect(ws_client).to receive(:disconnect)

        actor.connect_client(ws_client)

        expect(subject.connected?).to be false
      end

      it 'handles websocket connect errors' do
        expect(ws_client).to receive(:connect) do |&block|
          raise Kontena::Websocket::SSLVerifyError.new(OpenSSL::X509::V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT), 'certificate verify failed: self signed certificate'
        end
        expect(ws_client).to receive(:disconnect)

        expect(subject).to receive(:on_error).with(Kontena::Websocket::SSLVerifyError)
        expect(subject).to receive(:reconnect!)

        actor.connect_client(ws_client)

        expect(subject.connected?).to be false
      end

      it 'handles websocket read errors' do
        expect(ws_client).to receive(:connect)
        expect(subject).to receive(:on_open)
        expect(ws_client).to receive(:read) do |&block|
          raise Kontena::Websocket::TimeoutError, 'ping timeout'
        end
        expect(ws_client).to receive(:disconnect)

        expect(subject).to receive(:on_error).with(Kontena::Websocket::TimeoutError)
        expect(subject).to receive(:reconnect!)

        actor.connect_client(ws_client)

        expect(subject.connected?).to be false
      end

      it 'handles websocket close errors' do
        expect(ws_client).to receive(:connect)
        expect(subject).to receive(:on_open)

        expect(ws_client).to receive(:read) do |&block|
          raise Kontena::Websocket::CloseError.new(1337, 'testing')
        end
        expect(subject).to receive(:on_close).with(1337, 'testing')

        expect(ws_client).to receive(:disconnect)
        expect(subject).to receive(:reconnect!)

        actor.connect_client(ws_client)

        expect(subject.connected?).to be false
      end

      it 'handles websocket close' do
        expect(ws_client).to receive(:connect)
        expect(subject).to receive(:on_open)

        expect(ws_client).to receive(:read) do |&block|
          allow(ws_client).to receive(:close_code).and_return(1337)
          allow(ws_client).to receive(:close_reason).and_return 'testing'
        end
        expect(subject).to receive(:info).with('Agent closed connection with code 1337: testing')

        expect(ws_client).to receive(:disconnect)
        expect(subject).to receive(:reconnect!)

        actor.connect_client(ws_client)

        expect(subject.connected?).to be false
      end

      it 'handles unkonwn errors' do
        expect(ws_client).to receive(:connect) do |&block|
          fail 'test'
        end
        expect(ws_client).to receive(:disconnect)

        expect(subject).not_to receive(:on_error)
        expect(subject).to receive(:error)
        expect(subject).to receive(:reconnect!)

        actor.connect_client(ws_client)

        expect(subject.connected?).to be false
      end

      it 'crashes without reconnecting if on_close fails', :log_celluloid_actor_crashes => false do
        expect(ws_client).to receive(:connect)
        expect(subject).to receive(:on_open)

        expect(ws_client).to receive(:read) do |&block|
          raise Kontena::Websocket::CloseError.new(1337, 'testing')
        end
        expect(ws_client).to receive(:disconnect)

        expect(subject).not_to receive(:on_error)
        expect(subject).to receive(:on_close).with(1337, 'testing').and_raise(RuntimeError)

        expect(subject).to_not receive(:reconnect!)

        expect(subject).to receive(:close!) # actor crash => finalizer
        expect{actor.connect_client(ws_client)}.to raise_error(RuntimeError)
        expect{actor.ws}.to raise_error(Celluloid::DeadActorError)
        expect(actor.dead?).to be_truthy
      end

      it 'handles websocket pongs as async calls' do
        expect(ws_client).to receive(:connect)
        expect(subject).to receive(:on_open)
        expect(ws_client).to receive(:read) do |&block|
          expect(@on_pong).to_not be_nil

          expect(async).to receive(:on_pong).with(1.0)

          @on_pong.call(1.0)

          allow(ws_client).to receive(:close_code).and_return(1000)
          allow(ws_client).to receive(:close_reason).and_return ''
        end
        expect(subject).to_not receive(:on_error)

        expect(subject).to receive(:disconnected!).and_call_original
        expect(subject).to receive(:reconnect!)
        expect(ws_client).to receive(:disconnect)

        actor.connect_client(ws_client)
      end
    end

    describe '#ws' do
      it 'returns websocket client' do
        expect(subject.ws).to eq ws_client
      end
    end

    describe '#on_open' do
      context 'without ssl' do
        before do
          allow(ws_client).to receive(:ssl_cert!).and_return(nil)
          allow(ws_client).to receive(:ssl_verify?).and_return(false)
        end

        it 'updates connected and published websocket:open' do
          expect(subject).to receive(:info).with('unsecure connection established without SSL')
          expect(subject).to receive(:publish).with('websocket:open', nil)

          actor.on_open

          expect(subject.connected?).to be true
        end
      end

      context 'for a wss:// URL with ssl_verify' do
        let(:url) { 'wss://socket.example.com' }
        let(:ssl_params) { { verify_mode: OpenSSL::SSL::VERIFY_PEER }}

        before do
          allow(ws_client).to receive(:ssl_verify?).and_return(true)
        end

        it 'logs the subject and issuer of a verified cert' do
          expect(ws_client).to receive(:ssl_cert!).and_return(instance_double(OpenSSL::X509::Certificate,
            issuer: '/CN=ca',
            subject: '/CN=test',
          ))
          expect(subject).to receive(:info).with('secure connection established with KONTENA_SSL_VERIFY: /CN=test (issuer /CN=ca)')

          actor.on_open
        end
      end

      context 'for a wss:// URL without ssl verify' do
        let(:url) { 'wss://socket.example.com' }
        let(:ssl_params) { { verify_mode: OpenSSL::SSL::VERIFY_NONE }}

        before do
          allow(ws_client).to receive(:ssl_verify?).and_return(false)
        end

        it 'logs a warning about unverified cert' do
          expect(ws_client).to receive(:ssl_cert!).and_raise(Kontena::Websocket::SSLVerifyError.new(OpenSSL::X509::V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT), 'self signed certificate')
          expect(subject).to receive(:warn).with('insecure connection established with SSL errors: certificate verify failed: self signed certificate')

          actor.on_open
        end

        it 'logs a warning about verified cert' do
          expect(ws_client).to receive(:ssl_cert!).and_return(instance_double(OpenSSL::X509::Certificate,
            issuer: '/CN=ca',
            subject: '/CN=test',
          ))

          expect(subject).to receive(:warn).with('secure connection established without KONTENA_SSL_VERIFY=true: /CN=test (issuer /CN=ca)')

          actor.on_open
        end
      end
    end

    describe '#on_error' do
      let(:ssl_cert) { instance_double(OpenSSL::X509::Certificate,
        subject: OpenSSL::X509::Name.parse('/CN=test'),
        issuer: OpenSSL::X509::Name.parse('/CN=test-ca'),
      ) }

      it 'logs ssl verify errors with cert details' do
        expect(subject).to receive(:error).with("unable to connect to SSL server with KONTENA_SSL_VERIFY=true: certificate verify failed: self signed certificate (subject /CN=test, issuer /CN=test-ca)")

        subject.on_error(Kontena::Websocket::SSLVerifyError.new(OpenSSL::X509::V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT, ssl_cert, [], 'self signed certificate'))
      end

      it 'logs ssl verify errors' do
        expect(subject).to receive(:error).with("unable to connect to SSL server with KONTENA_SSL_VERIFY=true: certificate verify failed: self signed certificate")

        subject.on_error(Kontena::Websocket::SSLVerifyError.new(OpenSSL::X509::V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT, nil, [], 'self signed certificate'))
      end

      it 'logs ssl errors' do
        expect(subject).to receive(:error).with("unable to connect to SSL server: SSL_connect SYSCALL returned=5 errno=0 state=unknown state")

        subject.on_error(Kontena::Websocket::SSLConnectError.new('SSL_connect SYSCALL returned=5 errno=0 state=unknown state'))
      end

      it 'logs protocol errors' do
        expect(subject).to receive(:error).with("unexpected response from server, check url: Error during WebSocket handshake: Unexpected response code: 404")

        subject.on_error(Kontena::Websocket::ProtocolError.new('Error during WebSocket handshake: Unexpected response code: 404'))
      end

      it 'logs other errors' do
        expect(subject).to receive(:error).with("websocket error: testing")

        subject.on_error(Kontena::Websocket::Error.new('testing')) # XXX: other examples?
      end
    end

    describe '#disconnect' do
      it 'logs an error if the websocket close fails' do
        expect(ws_client).to receive(:close).and_raise(RuntimeError, "not connected")
        expect(subject).to receive(:error).with(/close failed/)

        actor.close!
      end
    end
  end

  context 'for a connected websocket client' do
    let(:ws_client) { instance_double(Kontena::Websocket::Client) }

    before do
      subject.instance_variable_set('@ws', ws_client)

      subject.connected!
    end
    after do
      # disable finalizer, or it will touch the rspec double outside of the test lifecycle
      subject.instance_variable_set('@ws', nil)
    end

    it 'is connected' do
      expect(subject.connected?).to be true
    end

    describe '#ws' do
      it 'returns websocket client' do
        expect(subject.ws).to eq ws_client
      end
    end

    describe '#send_message' do
      it 'sends message via websocket client' do
        expect(ws_client).to receive(:send).with('asdf')

        subject.send_message('asdf')
      end
    end
    describe '#send_notification' do
      it 'sends message via websocket client' do
        expect(ws_client).to receive(:send).with([147, 2, 165, 47, 116, 101, 115, 116, 145, 164, 97, 115, 100, 102])

        subject.send_notification('/test', ['asdf'])
      end
    end
    describe '#send_request' do
      it 'sends message via websocket client' do
        expect(ws_client).to receive(:send).with([148, 0, 1, 165, 47, 116, 101, 115, 116, 145, 164, 97, 115, 100, 102])

        subject.send_request(1, '/test', ['asdf'])
      end
    end

    describe '#on_message' do
      let(:rpc_request) { [0, 1, '/test', ['foo']] }
      let(:rpc_response) { [1, 1, '/test', ['foo']] }
      let(:rpc_notification) { [2, '/test', ['foo']] }

      let(:rpc_server) { instance_double(Kontena::RpcServer) }
      let(:rpc_server_async) { instance_double(Kontena::RpcServer) }
      let(:rpc_client) { instance_double(Kontena::RpcClient) }
      let(:rpc_client_async) { instance_double(Kontena::RpcClient) }

      before do
        allow(subject).to receive(:rpc_server).and_return(rpc_server)
        allow(subject).to receive(:rpc_client).and_return(rpc_client)

        allow(rpc_server).to receive(:async).and_return(rpc_server_async)
        allow(rpc_client).to receive(:async).and_return(rpc_client_async)
      end

      it 'passes an RPC request to the rpc server' do
        expect(rpc_server_async).to receive(:handle_request).with(actor, rpc_request)

        actor.on_message MessagePack.dump(rpc_request).bytes
      end

      it 'passes an RPC response to the rpc client' do
        expect(rpc_client_async).to receive(:handle_response).with(rpc_response)

        actor.on_message MessagePack.dump(rpc_response).bytes
      end

      it 'passes an RPC notification to the rpc server' do
        expect(rpc_server_async).to receive(:handle_notification).with(rpc_notification)

        actor.on_message MessagePack.dump(rpc_notification).bytes
      end
    end

    describe '#on_close' do
      it 'aborts on 4001 error code', log_celluloid_actor_crashes: false do
        expect(subject).to receive(:handle_invalid_token).and_call_original
        expect(Kontena::Agent).to receive(:shutdown)

        actor.on_close(4001, "Invalid token")
      end

      it 'aborts on 4010 error code', log_celluloid_actor_crashes: false do
        expect(subject).to receive(:handle_invalid_version).and_call_original
        expect(Kontena::Agent).to receive(:shutdown)

        actor.on_close(4010, "Invalid version")
      end

      it 'disconnects on 4030 error code' do
        expect(subject).to_not receive(:abort)

        actor.on_close(4030, "Invalid clock")
      end

      it 'aborts on 4040 error code', log_celluloid_actor_crashes: false do
        expect(subject).to receive(:handle_invalid_connection).and_call_original
        expect(Kontena::Agent).to receive(:shutdown)

        actor.on_close(4040, "Invalid node")
      end

      it 'aborts on 4041 error code', log_celluloid_actor_crashes: false do
        expect(subject).to receive(:handle_invalid_connection).and_call_original
        expect(Kontena::Agent).to receive(:shutdown)

        actor.on_close(4041, "Invalid connection")
      end
    end

    describe '#on_pong' do
      it "logs a warning if delay is over threshold", :em => false do
        sleep 0.05

        expect(subject).to receive(:warn).with(/server ping 3.20s of 5.00s timeout/)

        subject.on_pong(3.2)
      end
    end

    describe '#disconnected!' do
      it "reconnects" do
        expect(subject).to receive(:reconnect!)

        subject.disconnected!

        expect(subject).to_not be_connected
      end
    end

    describe '#reconnect!' do
      it "calls connect after initial backoff" do
        expect(subject.wrapped_object).to receive(:after) do |backoff, &block|
          expect(backoff).to be <= 1.0
          expect(subject.wrapped_object).to receive(:connect!)

          block.call
        end

        subject.reconnect!

        expect(subject).to be_reconnecting
      end
    end

    describe '#close!' do
      it 'closes the websocket client' do
        expect(ws_client).to receive(:close).with(1000, "Testing")

        actor.close! reason: "Testing"

        expect(subject).to be_closed
      end
    end

    context 'which is closed?' do
      before do
        expect(ws_client).to receive(:close)

        actor.close!
      end

      describe '#disconnected!' do
        it 'does not reconnect' do
          expect(subject).to_not receive(:reconnect!)

          actor.disconnected!

          expect(subject).to_not be_connected
        end
      end

      describe '#reconnect!' do
        it 'does not connect' do
          expect(subject).to receive(:reconnect_backoff).and_return(0)
          expect(subject).to_not receive(:connect!)

          actor.reconnect!
        end
      end
    end
  end

  describe '#request_message?' do
    it 'returns trus on request message' do
      msg = [0, 1, 1, 1]
      expect(subject.request_message?(msg)).to be_truthy
    end

    it 'returns false if not an request message' do
      msg = [1, 1, 1, 1]
      expect(subject.request_message?(msg)).to be_falsey
    end
  end

  describe '#notification_message?' do
    it 'returns trus if notification message' do
      msg = [2, 1, 1]
      expect(subject.notification_message?(msg)).to be_truthy
    end
  end
end

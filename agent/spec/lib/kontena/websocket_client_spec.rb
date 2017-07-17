describe Kontena::WebsocketClient do
  let(:api_uri) { 'http://test' }
  let(:node_id) { 'ABCD' }
  let(:grid_token) { 'test' }
  let(:node_token) { nil }
  let(:node_labels) { ['region=test'] }

  let(:subject) {
    described_class.new(api_uri, node_id,
      grid_token: grid_token,
      node_token: node_token,
      node_labels: node_labels,
    )
  }

  before(:each) {
    Celluloid.boot
  }
  after(:each) { Celluloid.shutdown }

  around(:each, :em => true) do |example|
    EM.run {
      example.run
      EM.stop
    }
  end

  describe '#connected?' do
    it 'returns false by default' do
      expect(subject.connected?).to eq(false)
    end

    it 'returns true if connection is established' do
      subject.on_open(spy(:event))
      expect(subject.connected?).to eq(true)
    end
  end

  describe '#connect' do
    it 'sets connecting to true' do
      expect {
        subject.connect
      }.to change{ subject.connecting? }.from(false).to(true)
    end

    it 'sets connected to false' do
      subject.on_open(spy)
      expect {
        subject.connect
      }.to change{ subject.connected? }.from(true).to(false)
    end
  end

  describe '#on_open' do
    it 'sets connected to true' do
      expect(subject.connected?).to be_falsey
      subject.on_open(spy)
      expect(subject.connected?).to be_truthy
    end

    it 'sets connecting to false' do
      subject.connect
      expect(subject.connecting?).to be_truthy
      subject.on_open(spy)
      expect(subject.connecting?).to be_falsey
    end

    it 'cancels ping timer' do
      timer = spy(:timer)
      allow(subject).to receive(:ping_timer).and_return(timer)
      expect(timer).to receive(:cancel)
      subject.on_open(spy)
    end
  end

  describe '#on_error' do
    context "For a server that is ECONNREFUSED" do
      subject do
        described_class.new('ws://127.0.0.1:1337', node_id, grid_token: 'test-token')
      end

      it "logs an error", :em => false do
        expect(subject).to receive(:error).with(/connection refused/) do |event|
          EM.stop
        end

        # XXX: EM will segfault if the mock raises
        # =>   https://github.com/eventmachine/eventmachine/issues/765
        EM.run {
          subject.connect
        }
      end
    end
  end

  describe '#on_close' do
    let(:event) { Faye::WebSocket::API::CloseEvent.new('close', {}) }

    before do
      allow(EM).to receive(:next_tick) do |&block| block.call end
    end

    it 'sets connected to false' do
      subject.on_open(spy)
      expect {
        subject.on_close(event)
      }.to change{ subject.connected? }.from(true).to(false)
    end

    it 'sets connecting to false' do
      subject.instance_variable_set('@connecting', true)
      expect {
        subject.on_close(event)
      }.to change{ subject.connecting? }.from(true).to(false)
    end

    it 'aborts on 4001 error code' do
      event = Faye::WebSocket::API::CloseEvent.new('close', code: 4001)
      expect(subject).to receive(:handle_invalid_token).and_call_original
      expect(subject).to receive(:abort)
      subject.on_close(event)
    end

    it 'aborts on 4010 error code' do
      event = Faye::WebSocket::API::CloseEvent.new('close', code: 4010)
      expect(subject).to receive(:handle_invalid_version).and_call_original
      expect(subject).to receive(:abort)
      subject.on_close(event)
    end

    it 'disconnects on 4030 error code' do
      event = Faye::WebSocket::API::CloseEvent.new('close', code: 4030)
      expect(subject).to_not receive(:abort)
      subject.on_close(event)
    end

    it 'aborts on 4040 error code' do
      event = Faye::WebSocket::API::CloseEvent.new('close', code: 4040)
      expect(subject).to receive(:handle_invalid_connection).and_call_original
      expect(subject).to receive(:abort)
      subject.on_close(event)
    end

    it 'aborts on 4041 error code' do
      event = Faye::WebSocket::API::CloseEvent.new('close', code: 4040)
      expect(subject).to receive(:handle_invalid_connection).and_call_original
      expect(subject).to receive(:abort)
      subject.on_close(event)
    end

    it 'publishes websocket:close' do
      expect(Celluloid::Notifications).to receive(:publish).with('websocket:close', nil)
      subject.on_close(event)
    end
  end

  describe '#verify_connection' do
    let :ws do
      instance_double(Faye::WebSocket::Client)
    end

    before do
      stub_const("Kontena::WebsocketClient::PING_TIMEOUT", 0.1)
      allow(subject).to receive(:ws).and_return(ws)
    end

    it "logs a warning if delay is over threshold", :em => false do
      expect(ws).to receive(:ping) do |&block|
        sleep 0.05

        block.call

        EM.stop
      end

      expect(subject).to receive(:warn).with(/keepalive ping \d+.\d+s/)

      EM.run {
        subject.verify_connection
      }
    end

    it "logs an error and closes the connection if over timeout", :em => false do
      expect(ws).to receive(:ping) do |&block|
        # nothing, let the ping timer expire
      end

      expect(subject).to receive(:connected?).and_return(true)
      expect(subject).to receive(:error).with(/keepalive ping \d+.\d+s timeout/)

      expect(subject).to receive(:close) do
        EM.stop
      end

      EM.run {
        subject.verify_connection
      }
    end
  end

  describe '#close' do
    let :ws do
      instance_double(Faye::WebSocket::Client)
    end

    before do
      allow(subject).to receive(:ws).and_return(ws)
    end

    it 'publishes event', :em => true do
      expect(Celluloid::Notifications).to receive(:publish).with('websocket:disconnect', nil)
      expect(ws).to receive(:close)
      subject.close
    end

    context "for a connected websocket", :em => true do
      let :open_event do
        double(:open_event)
      end
      let :close_event do
        double(:close_event, code: 1006, reason: "Connection closed")
      end

      let :close_timer do
        instance_double(EM::Timer)
      end

      before do
        subject.on_open open_event

        expect(subject).to be_connected
        expect(subject).to_not be_connecting
      end

      it 'eventually sets connection to closed ' do
        expect(Celluloid::Notifications).to receive(:publish).with('websocket:disconnect', nil)

        expect(ws).to receive(:close) { }

        subject.close

        expect(subject).to be_connected
        expect(subject).to_not be_connecting

        expect(Celluloid::Notifications).to receive(:publish).with('websocket:close', nil)

        subject.on_close close_event

        expect(subject).to_not be_connected
        expect(subject).to_not be_connecting
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

  describe '#send_message' do
    it 'does not raise error if ws is nil' do
      allow(subject).to receive(:@ws).and_return(nil)
      expect {
        subject.send_message('foo')
      }.not_to raise_error
    end
  end
end

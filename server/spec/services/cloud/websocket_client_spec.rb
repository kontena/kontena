require_relative '../../spec_helper'
describe Cloud::WebsocketClient do
  let(:client_id) { 'client_id'}
  let(:client_secret) { 'client_secret' }

  let(:subject) do
    described_class.new(client_id, client_secret)
  end

  let(:valid_headers) do
    { 'Authorization' => "Basic #{Base64.urlsafe_encode64(client_id+':'+client_secret)}" }
  end

  let(:ws) do
    spy
  end

  let(:rpc_server_mock) do
    double
  end

  before(:each) do
    allow(Cloud::WebsocketClient).to receive(:api_uri).and_return('ws://localhost')
    allow(Faye::WebSocket::Client).to receive(:new)
      .with('ws://localhost/platform', nil, headers: valid_headers)
      .and_return(ws)
  end


  describe '#connect' do
    it 'does not connect if client is already connecting' do
      expect(subject).to receive(:connecting?).and_return(true)
      expect(Faye::WebSocket::Client).not_to receive(:new)
      subject.connect
    end

    it 'sets connecting to true' do
      subject.connect
      expect(subject.connecting?).to be_truthy
    end

    it 'sets connected to false' do
      subject.connect
      expect(subject.connected?).to be_falsey
    end

    it 'opens websocket connection with basic auth credentials' do
      expect(Faye::WebSocket::Client).to receive(:new)
        .with('ws://localhost/platform', nil, headers: valid_headers)
        .and_return(ws)
      subject.connect
    end
  end

  describe '#on_open' do
    it 'subscribes model event streams' do
      expect(MongoPubsub).to receive(:subscribe).with(EventStream.channel)
      subject.on_open(spy(:event))
    end

    it 'sets connecting to false' do
      subject.on_open(spy(:event))
      expect(subject.connecting?).to be_falsey
    end

    it 'sets connected to true' do
      subject.on_open(spy(:event))
      expect(subject.connected?).to be_truthy
    end
  end

  describe '#on_message' do
    context 'when instance is leader' do
      before(:each) do
        allow(subject).to receive(:leader?).and_return(true)
        allow(subject).to receive(:rpc_server).and_return(rpc_server_mock)
      end

      context 'on rpc request' do
        it 'requests RPC::Server::Api' do
          event = double
          msg = MessagePack.dump([0,'12345','method',['params']]).bytes
          allow(event).to receive(:data).and_return(msg)
          expect(rpc_server_mock).to receive(:handle_request) {
            EM.stop
          }.and_return({})
          EM.run {
            subject.connect
            subject.on_message(event)
          }

        end

        it 'sends response message with MessagePack rpc result' do
          event = double
          msg = MessagePack.dump([0,'12345','method',['params']]).bytes
          allow(event).to receive(:data).and_return(msg)
          rpc_result = 'response'
          packaged_rpc_result = MessagePack.dump(rpc_result).bytes
          allow(rpc_server_mock).to receive(:handle_request).and_return(rpc_result)
          expect(ws).to receive(:send).with(packaged_rpc_result) {
            EM.stop
          }
          EM.run {
            subject.connect
            subject.on_message(event)
          }
        end
      end
    end
  end

  describe '#on_close' do

    it 'sets connecting to false' do
      subject.connect
      subject.on_close(spy(:event))
      expect(subject.connecting?).to be_falsey
    end

    it 'sets connected to false' do
      subject.connect
      subject.on_open(spy(:event))
      subject.on_close(spy(:event))
      expect(subject.connected?).to be_falsey
    end

    it 'unsubscribes from event streams' do
      subscription = double
      allow(MongoPubsub).to receive(:subscribe).and_return(subscription)
      subject.on_open(spy(:event))

      expect(MongoPubsub).to receive(:unsubscribe).with(subscription)
      subject.on_close(spy(:event))
    end
  end

  describe '#send_notification' do
    let(:grid) do
      grid = Grid.create!(name: 'test')
      grid.users << john
      grid
    end

    let(:john) do
      User.create(email: 'john.doe@example.org', external_id: '12345')
    end

    let(:jane) do
      User.create(email: 'jane.doe@example.org', external_id: '67890')
    end

    it 'sends notification message' do
      grid  #create
      message = {
        type: 'GridService',
        event: 'create',
        object: { name: "test-service", grid: { id: "test"} }
      }
      expect(ws).to receive(:send).once do
          EM.stop
      end

      EM.run {
        subject.connect
        subject.send_notification_message(message)
      }
    end

    context 'message' do
      it 'is right formatted' do
        grid  #create
        message = {
          type: 'GridService',
          event: 'create',
          object: {"name": "test-service", "grid": {"id": "test"}}
        }

        expect(ws).to receive(:send).once do |param|
            message = MessagePack.unpack(param.pack('c*'))
            expect(message).to be_instance_of(Array)
            expect(message[0]).to eq(2)
            expect(message[1]).to eq('GridService#create')
            expect(message[2]).to be_instance_of(Array)
            EM.stop
        end

        EM.run {
          subject.connect
          subject.send_notification_message(message)
        }
      end

      context 'params' do
        it 'contains grid as first entry' do
          grid  #create
          message = {
            type: 'GridService',
            event: 'create',
            object: { "name" => "test-service", "grid" => { "id" => "test" }}
          }

          expect(ws).to receive(:send).once do |param|
              message = MessagePack.unpack(param.pack('c*'))
              expect(message).to be_instance_of(Array)
              expect(message[2][0]).to eq('test')
              EM.stop
          end

          EM.run {
            subject.connect
            subject.send_notification_message(message)
          }
        end

        it 'contains users as second entry' do
          grid  #create
          message = {
            type: 'GridService',
            event: 'create',
            object: { "name" => "test-service", "grid" => { "id" => "test" }}
          }

          expect(ws).to receive(:send).once do |param|
              message = MessagePack.unpack(param.pack('c*'))
              expect(message).to be_instance_of(Array)
              expect(message[2][1].include?(john.external_id)).to be_truthy
              expect(message[2][1].include?(jane.external_id)).to be_falsey
              EM.stop
          end

          EM.run {
            subject.connect
            subject.send_notification_message(message)
          }
        end

        it 'contains object as third entry' do
          grid  #create
          message = {
            type: 'GridService',
            event: 'create',
            object: { "name" => "test-service", "grid" => { "id" => "test" }}
          }

          expect(ws).to receive(:send).once do |param|
              message = MessagePack.unpack(param.pack('c*'))
              expect(message).to be_instance_of(Array)
              expect(message[2][2]).to eq({"name" => "test-service", "grid" => {"id" => "test"}})
              EM.stop
          end

          EM.run {
            subject.connect
            subject.send_notification_message(message)
          }
        end
      end
    end
  end
end

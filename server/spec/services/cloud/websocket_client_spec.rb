describe Cloud::WebsocketClient, :celluloid => true do
  let(:api_uri) { 'wss://socket.kontena.io/platform' }
  let(:client_id) { 'client_id'}
  let(:client_secret) { 'client_secret' }

  let(:subject) do
    described_class.new(api_uri,
      client_id: client_id,
      client_secret: client_secret,
    )
  end
  let(:async_proxy) { instance_double(described_class) }

  let(:valid_headers) do
    { 'Authorization' => "Basic #{Base64.urlsafe_encode64(client_id+':'+client_secret)}" }
  end

  let(:ws) { instance_double(Kontena::Websocket::Client,
    url: api_uri,
  ) }

  let(:rpc_server_mock) do
    double
  end

  before do
    allow(subject.wrapped_object).to receive(:async).and_return(async_proxy)

    # for testing #start
    allow(subject.wrapped_object).to receive(:every) do |&block|
      block.call
    end
  end

  context 'for a disconnected client' do
    it 'is not connected' do
      expect(subject.connected?).to be false
    end

    it 'is not connecting' do
      expect(subject.connecting?).to be false
    end

    describe '#start' do
      it 'connects' do
        expect(subject.wrapped_object).to receive(:connect)

        subject.start
      end
    end

    describe '#connect' do
      before do
        allow(Kontena::Websocket::Client).to receive(:new)
          .with('wss://socket.kontena.io/platform', hash_including(
            headers: valid_headers,
          ))
          .and_return(ws)
      end

      it 'creates a websocket client and calls connect_client' do
        expect(async_proxy).to receive(:connect_client).with(ws)

        subject.connect

        expect(subject).to be_connecting
        expect(subject).to_not be_connected
      end
    end

    describe '#send_notification' do
      it 'logs warning' do
        message = {
          type: 'Test',
          event: 'test',
          object: {"name": "test", "grid": {}}
        }

        expect(subject.wrapped_object).to receive(:warn).with("failed to send message: not connected")

        subject.send_notification_message(message)
      end
    end
  end

  context 'for a connecting websocket client' do
    before do
      subject.wrapped_object.instance_variable_set('@connecting', true)
      subject.wrapped_object.instance_variable_set('@ws', ws)
    end

    it 'is not connected' do
      expect(subject.connected?).to be false
    end

    it 'is connecting' do
      expect(subject.connecting?).to be true
    end

    describe '#start' do
      it 'does not connect' do
        expect(subject.wrapped_object).not_to receive(:connect)

        subject.start
      end
    end

    describe '#connect_client' do
      it 'runs the websocket client in a separate thread' do
        expect(ws).to receive(:connect) do
          expect(Celluloid.actor?).to be false
        end
        expect(subject.wrapped_object).to receive(:on_open) do
          expect(Celluloid.actor?).to be true
          expect(Celluloid.current_actor).to eq subject
        end

        expect(ws).to receive(:read) do |&block|
          expect(subject.wrapped_object).to receive(:on_message).with('test')

          block.call 'test'

          raise Kontena::Websocket::CloseError.new(1337, 'testing')
        end
        expect(subject.wrapped_object).to_not receive(:on_error)
        expect(subject.wrapped_object).to receive(:on_close).with(1337, 'testing')

        expect(ws).to receive(:disconnect)

        subject.connect_client(ws)
      end
    end

    describe '#on_open' do
      context 'without ssl' do
        before do
          allow(ws).to receive(:ssl_cert!).and_return(nil)
          allow(ws).to receive(:ssl_verify?).and_return(false)
        end

        it 'subscribes model event streams' do
          expect(MongoPubsub).to receive(:subscribe).with(EventStream.channel)

          subject.on_open

          expect(subject.connecting?).to be false
          expect(subject.connected?).to be true
        end
      end
    end
  end

  context 'for a connected client' do
    before do
      subject.wrapped_object.instance_variable_set('@connected', true)
      subject.wrapped_object.instance_variable_set('@ws', ws)
    end

    it 'is not connecting' do
      expect(subject.connecting?).to be false
    end

    it 'is connected' do
      expect(subject.connected?).to be true
    end

    describe '#start' do
      it 'does not connect' do
        expect(subject.wrapped_object).not_to receive(:connect)

        subject.start
      end
    end

    describe '#on_message' do
      context 'when instance is leader' do
        before(:each) do
          allow(subject.wrapped_object).to receive(:leader?).and_return(true)
          allow(subject.wrapped_object).to receive(:rpc_server).and_return(rpc_server_mock)
        end

        context 'on rpc request' do
          it 'requests RPC::Server::Api and sends response' do
            msg = MessagePack.dump([0,'12345','method',['params']]).bytes

            expect(rpc_server_mock).to receive(:handle_request).and_return('response')
            expect(ws).to receive(:send).with(MessagePack.dump('response').bytes)

            subject.on_message(msg)
          end
        end
      end
    end

    describe '#on_close' do
      let(:subscription) { instance_double(MongoPubsub::Subscription) }

      before do
        subject.wrapped_object.instance_variable_set('@subscription', subscription)
      end

      it 'marks client as disconnected' do
        expect(subject.wrapped_object).to receive(:unsubscribe_events)

        subject.on_close(1337, 'testing')

        expect(subject.connecting?).to be false
        expect(subject.connected?).to be false
      end

      it 'cleans up subscription' do
        expect(MongoPubsub).to receive(:unsubscribe).with(subscription)

        subject.on_close(1337, 'testing')
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
        expect(ws).to receive(:send)

        subject.send_notification_message(message)
      end

      describe 'message' do
        it 'is correctly formatted' do
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
          end

          subject.send_notification_message(message)
        end

        describe 'params' do
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
            end

            subject.send_notification_message(message)
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
            end

            subject.send_notification_message(message)
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
            end

            subject.send_notification_message(message)
          end
        end
      end
    end

    describe '#subscribe_events' do
      let(:event) do
        {
          type: 'Test',
          event: 'test',
          object: {"name": "test", "grid": {}}
        }
      end

      context 'with an active subscription' do
        before do
          expect(subject.subscribe_events).to be_a MongoPubsub::Subscription
        end

        after do
          subject.unsubscribe_events
        end

        context 'for a leader' do
          before do
            allow(subject.wrapped_object).to receive(:leader?).and_return(true)
          end

          it 'sends notifications for published events' do
            @ok = false

            expect(subject.wrapped_object).to receive(:send_notification_message).with(event) do
              expect(Celluloid.actor?).to be_truthy
              expect(Celluloid.current_actor).to eq subject

              @ok = true
            end

            MongoPubsub.publish(EventStream.channel, event)

            WaitHelper.wait_until!(timeout: 1.0, interval: 0.1) { @ok }
          end
        end
      end
    end
  end
end

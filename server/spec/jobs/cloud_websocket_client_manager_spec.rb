
describe CloudWebsocketClientManager, celluloid: true do
  let(:subject) { described_class.new(false) }

  let(:config) { double() }
  let(:config_cloud_uri) { 'wss://socket.kontena.io' }
  let(:config_client_id) { 'asdf' }
  let(:config_client_secret) { 'secret' }

  before(:each) {
    allow(subject.wrapped_object).to receive(:config).and_return(config)
    allow(config).to receive(:[]).with('cloud.socket_uri').and_return(config_cloud_uri)
    allow(config).to receive(:[]).with('oauth2.client_id').and_return(config_client_id)
    allow(config).to receive(:[]).with('oauth2.client_secret').and_return(config_client_secret)
  }

  describe '#perform' do
    it 'calls update_connection at start, and then every' do
      expect(subject.wrapped_object).to receive(:update_connection).once
      expect(subject.wrapped_object).to receive(:every) do |&block|
        expect(subject.wrapped_object).to receive(:update_connection).once

        block.call
      end

      subject.perform
    end
  end

  describe '#update_connection' do
    context 'when cloud is enabled' do
      before(:each) do
        allow(subject.wrapped_object).to receive(:cloud_enabled?).and_return(true)
      end

      it 'connects to websocket server' do
        expect(subject.wrapped_object).to receive(:connect).once.with('wss://socket.kontena.io/platform',
          client_id: 'asdf',
          client_secret: 'secret',
        )
        subject.update_connection
      end
    end

    context 'when cloud is disabled' do
      before(:each) do
        allow(subject.wrapped_object).to receive(:cloud_enabled?).and_return(false)
      end

      it 'disconnects from websocket server' do
        expect(subject.wrapped_object).to receive(:disconnect).once
        subject.update_connection
      end
    end

    describe '#connect' do
      let(:websocket_client) { instance_double(Cloud::WebsocketClient) }
      it 'initializes and starts websocket client from config' do
        expect(Cloud::WebsocketClient).to receive(:new).with('wss://socket.kontena.io/platform',
          client_id: 'asdf',
          client_secret: 'secret',
        ).and_return(websocket_client)
        expect(websocket_client).to receive(:start)
        expect(subject.wrapped_object).to receive(:link).with(websocket_client)

        expect(subject.connect('wss://socket.kontena.io/platform',
          client_id: 'asdf',
          client_secret: 'secret',
        )).to eq websocket_client
      end
    end

    context 'with a connected client' do
      let(:client) { instance_double(Cloud::WebsocketClient) }
      before do
        subject.wrapped_object.instance_variable_set('@client', client)
      end

      describe '#disconnect' do
        it 'stops the websocket client' do
          expect(client).to receive(:stop)

          subject.disconnect
        end
      end

      describe '#on_actor_exit' do
        it 'sets client to nil' do
          subject.send :on_actor_exit, client, RuntimeError.new('test')

          expect(subject.send :client).to be nil
        end
      end
    end

    describe '#cloud_enabled?' do
      context 'when auth provider is kontena and oauth app credentials are present and cloud is enabled in config and socket api uri is configured' do
        it 'returns true' do
          allow(subject.wrapped_object).to receive(:kontena_auth_provider?)
            .and_return(true)
          allow(subject.wrapped_object).to receive(:oauth_app_credentials?)
            .and_return(true)
          allow(subject.wrapped_object).to receive(:cloud_enabled_in_config?)
            .and_return(true)
          allow(subject.wrapped_object).to receive(:socket_api_uri?)
            .and_return(true)
          expect(subject.cloud_enabled?).to be_truthy
        end
      end
      context 'when settings are invalid' do
        it 'returns false' do
          allow(subject.wrapped_object).to receive(:kontena_auth_provider?)
            .and_return(true)
          allow(subject.wrapped_object).to receive(:oauth_app_credentials?)
            .and_return(true)
          allow(subject.wrapped_object).to receive(:cloud_enabled_in_config?)
            .and_return(true)
          allow(subject.wrapped_object).to receive(:socket_api_uri?)
            .and_return(false)
          expect(subject.cloud_enabled?).to be_falsey
        end
      end
    end
  end
end


describe CloudWebsocketConnectJob, celluloid: true do

  let(:subject) { described_class.new(false) }
  let(:config) { spy }
  before(:each) {
    allow(subject).to receive(:start_em).and_return(true)
    allow(subject.wrapped_object).to receive(:config).and_return(config)
  }

  describe '#perform' do

    context 'when cloud enabled' do
      before(:each) do
        allow(subject.wrapped_object).to receive(:running?).and_return(true, false)
        allow(subject.wrapped_object).to receive(:cloud_enabled).and_return(true)
        allow(subject.wrapped_object).to receive(:sleep).and_return(true)
      end

      it 'update connection' do
        expect(subject.wrapped_object).to receive(:update_connection).once
        subject.perform
      end
    end
  end

  describe '#update_connection' do
    before(:each) do
      allow(subject.wrapped_object).to receive(:running?).and_return(true, false)
      allow(subject.wrapped_object).to receive(:cloud_enabled).and_return(true)
      allow(subject.wrapped_object).to receive(:sleep).and_return(true)
    end

    context 'when cloud is enabled' do
      it 'connects to websocket server' do
        allow(subject.wrapped_object).to receive(:cloud_enabled?).and_return(true)
        expect(subject.wrapped_object).to receive(:connect).once
        subject.update_connection
      end
    end

    context 'when cloud is disabled' do
      it 'disconnects from websocket server' do
        allow(subject.wrapped_object).to receive(:cloud_enabled?).and_return(false)
        expect(subject.wrapped_object).to receive(:disconnect).once
        subject.update_connection
      end
    end

    describe '#connect' do
      it 'inits CloudWebSocketClient with client_id, client_secret from config' do
        allow(subject.wrapped_object).to receive(:config).and_return({
          'oauth2.client_id' => 'client_id',
          'oauth2.client_secret' => 'client_secret'
        })
        expect(subject.wrapped_object).to receive(:init_ws_client)
          .with('client_id', 'client_secret')
          .and_return(spy)
        subject.connect
      end

      it 'request websocket client to ensure connect' do
        allow(subject.wrapped_object).to receive(:config).and_return({
          'oauth2.client_id' => 'client_id',
          'oauth2.client_secret' => 'client_secret'
        })
        client = double
        allow(subject.wrapped_object).to receive(:init_ws_client)
          .with('client_id', 'client_secret')
          .and_return(client)
        expect(client).to receive(:ensure_connect).once
        subject.connect
      end
    end

    describe '#disconnect' do
      it 'request websocket client to disconnect' do
        client = spy
        allow(subject.wrapped_object).to receive(:init_ws_client)
          .and_return(client)
        subject.connect
        expect(client).to receive(:disconnect)
        subject.disconnect
      end

      it 'sets client to nil' do
        client = spy
        allow(subject.wrapped_object).to receive(:init_ws_client)
          .and_return(client)
        subject.connect
        subject.disconnect
        client = subject.send(:client)
        expect(client).to be_nil
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

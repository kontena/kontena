require 'kontena_cli'
require 'ostruct'

describe Kontena::Client do

  let(:subject) { described_class.new('https://localhost/v1/') }
  let(:http_client) { double(:http_client) }

  # This trickery is here for making the tests work with or without the new configuration handler.
  # The client itself will work with any kind of token that acts like a hash or ostruct.
  let(:server_class)   { Kontena::Cli.const_defined?('Config', false) ? Kontena::Cli::Config::Server  : OpenStruct }
  let(:token_class)    { Kontena::Cli.const_defined?('Config', false) ? Kontena::Cli::Config::Token   : OpenStruct }
  let(:account_class)  { Kontena::Cli.const_defined?('Config', false) ? Kontena::Cli::Config::Account : OpenStruct }

  let(:master) { server_class.new(url: 'https://localhost', name: 'master') }
  let(:token) { token_class.new(access_token: '1234', refresh_token: '5678', expires_at: nil, parent_type: :master, parent_name: 'master') }
  let(:expiring_token) { token_class.new(access_token: '1234', refresh_token: '5678', expires_at: Time.now.utc + 1000, parent_type: :master, parent_name: 'master') }
  let(:expired_token) { token_class.new(access_token: '1234', refresh_token: '5678', expires_at: Time.now.utc - 1000, parent_type: :master, parent_name: 'master') }

  before(:each) do
    allow(subject).to receive(:http_client).and_return(http_client)
    if Kontena::Cli.const_defined?('Config', false)
      config = Kontena::Cli::Config
    else
      config = Class.new { include Kontena::Cli::Common}.new
    end
    config.servers << master
    allow(config).to receive(:find_server).and_return(master)
    allow(config).to receive(:current_master).and_return(master)
    allow(config).to receive(:account).and_return(account_class.new(token_verify_path: '/v1/user', token_endpoint: '/oauth2/token', authorization_endpoint: '/oauth2/authorize'))
    allow(config).to receive(:write).and_return(true)
  end

  context 'token authentication' do

    it 'takes a token' do
      client = Kontena::Client.new('https://localhost/v1/', token)
      expect(client.token).to eq token
    end

    it 'uses the access token as a bearer token' do
      client = Kontena::Client.new('https://localhost/v1/', token)
      expect(client.http_client).to receive(:request) do |opts|
        expect(opts[:headers]['Authorization']).to eq "Bearer #{token.access_token}"
      end.and_return(spy(:response, status: 200))
      client.get('/v1/foo')
    end

    it 'does not try to refresh an expiring token that is still valid' do
      client = Kontena::Client.new('https://localhost/v1/', expiring_token)
      expect(client.http_client).to receive(:request) do |opts|
        expect(opts[:headers]['Authorization']).to eq "Bearer #{token.access_token}"
      end.and_return(spy(:response, status: 200))
      client.get('/v1/foo')
    end

    it 'tries to refresh an expired token' do
      master.token = expired_token
      client = Kontena::Client.new(master.url, master.token)
      allow(client).to receive(:token_refresh_path).and_return('/oauth2/token')
      expect(client.http_client).to receive(:request).with(hash_including(path: '/oauth2/token', method: :post)).and_return(OpenStruct.new(status: 201, headers: {'Content-Type' => 'application/json'}, body: '{"access_token": "abcd"}'))
      expect(client.http_client).to receive(:request).with(hash_including(path: '/v1/foo')) do |args|
        expect(args[:headers]['Authorization']).to eq "Bearer abcd"
      end.and_return(spy(:response, status: 200))
      client.get('/v1/foo')
    end
  end

  describe '#get' do
    it 'passes path to client' do
      allow(subject).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:request).with(
        hash_including(path: '/v1/foo', method: :get)
      ).and_return(spy(:response, status: 200))
      subject.get('foo')
    end

    it 'passes params to client' do
      allow(subject).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:request).with(
        hash_including(query: {bar: 'baz'}, method: :get)
      ).and_return(spy(:response, status: 200))
      subject.get('foo', {bar: 'baz'})
    end

    it 'passes params to client' do
      allow(subject).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:request).with(
        hash_including(headers: hash_including('Some-Header' => 'value'), method: :get)
      ).and_return(spy(:response, status: 200))
      subject.get('foo', nil, {'Some-Header' => 'value'})
    end
  end

  describe '#get_stream' do
    let(:response_block) { Proc.new{ } }

    it 'passes path & response_block to client' do
      allow(subject).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:request).with(
        hash_including(path: '/v1/foo', response_block: response_block, method: :get)
      ).and_return(spy(:response, status: 200))
      subject.get_stream('foo', response_block)
    end

    it 'passes params to client' do
      allow(subject).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:request).with(
        hash_including(query: {bar: 'baz'}, method: :get)
      ).and_return(spy(:response, status: 200))
      subject.get_stream('foo', response_block, {bar: 'baz'})
    end

    it 'passes params to client' do
      allow(subject).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:request).with(
        hash_including(headers: hash_including('Some-Header' => 'value'), method: :get)
      ).and_return(spy(:response, status: 200))
      subject.get_stream('foo', response_block, nil, {'Some-Header' => 'value'})
    end
  end

  describe '#post' do
    let(:data) do
      { foo: 'bar' }
    end

    it 'passes path and object to client' do
      allow(subject).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:request).with(
        hash_including(path: '/v1/foo', body: kind_of(String), method: :post)
      ).and_return(spy(:response, status: 200))
      subject.post('foo', data)
    end

    it 'passes params to client' do
      allow(subject).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:request).with(
        hash_including(query: {bar: 'baz'}, method: :post)
      ).and_return(spy(:response, status: 200))
      subject.post('foo', data, {bar: 'baz'})
    end

    it 'passes params to client' do
      allow(subject).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:request).with(
        hash_including(headers: hash_including('Some-Header' => 'value'), method: :post)
      ).and_return(spy(:response, status: 200))
      subject.post('foo', data, nil, {'Some-Header' => 'value'})
    end
  end

  describe '#put' do
    let(:data) do
      { foo: 'bar' }
    end

    it 'passes path and object to client' do
      allow(subject).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:request).with(
        hash_including(path: '/v1/foo', body: kind_of(String), method: :put)
      ).and_return(spy(:response, status: 200))
      subject.put('foo', data)
    end

    it 'passes params to client' do
      allow(subject).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:request).with(
        hash_including(query: {bar: 'baz'}, method: :put)
      ).and_return(spy(:response, status: 200))
      subject.put('foo', data, {bar: 'baz'})
    end

    it 'passes params to client' do
      allow(subject).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:request).with(
        hash_including(headers: hash_including('Some-Header' => 'value'), method: :put)
      ).and_return(spy(:response, status: 200))
      subject.put('foo', data, nil, {'Some-Header' => 'value'})
    end
  end

  describe '#delete' do
    let(:data) do
      { foo: 'bar' }
    end

    it 'passes path to client' do
      allow(subject).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:request).with(
        hash_including(path: '/v1/foo', method: :delete)
      ).and_return(spy(:response, status: 200))
      subject.delete('foo')
    end

    it 'passes params to client' do
      allow(subject).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:request).with(
        hash_including(query: {bar: 'baz'}, method: :delete)
      ).and_return(spy(:response, status: 200))
      subject.delete('foo', nil, {bar: 'baz'})
    end

    it 'passes params to client' do
      allow(subject).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:request).with(
        hash_including(headers: hash_including('Some-Header' => 'value'), method: :delete)
      ).and_return(spy(:response, status: 200))
      subject.delete('foo', nil, nil, {'Some-Header' => 'value'})
    end
  end

  describe '#request' do
    subject do
      Kontena::Client.new('http://localhost', master.token)
    end

    context "for an expected response" do
      before :each do
        allow(subject).to receive(:http_client).and_call_original

        WebMock.stub_request(:any, 'http://localhost/v1/test').to_return(
        status: 200,
        headers: {
          'Content-Type' => 'application/json',
        },
        body: {'test' => [ "This was a triumph.", "I’m making a note here: HUGE SUCCESS." ]}.to_json,
      )
      end

      it "returns the JSON object" do
        expect(subject.get('test')['test'].join(" / ")).to eq "This was a triumph. / I’m making a note here: HUGE SUCCESS."
      end
    end

    context "with an empty error response" do
      before :each do
        # workaround https://github.com/bblimke/webmock/issues/653
        expect(http_client).to receive(:request).with(
          hash_including(path: '/v1/coffee', method: :brew)
        ) {
          raise Excon::Errors::HTTPStatusError.new("I'm a teapot",
            {
              method: 'brew',
              path: '/v1/coffee',
            },
            double(:response,
              status: 418,
              path: '/foo',
              reason_phrase: "I'm a teapot",
              headers: {
                'Content-Type' => 'short/stout',
              },
              body: "",
            )
          )
        }
      end

      it "raises StandardError with the status phrase" do
        expect{subject.request(http_method: :brew, path: 'coffee')}.to raise_error(Kontena::Errors::StandardError, /I'm a teapot/)
      end
    end

    context "with an 500 response with text error" do
      before :each do
        allow(subject).to receive(:http_client).and_call_original

        WebMock.stub_request(:any, 'http://localhost/v1/print').to_return(
          status: 500,
          body: "lp0 (printer) on fire",
        )
      end

      it "raises StandardError with the server error message" do
        expect{subject.post('print', { 'code' => "8A/HyA==" })}.to raise_error(Kontena::Errors::StandardError, /lp0 \(printer\) on fire/)
      end
    end

    context "with a 422 response with JSON error string" do
      before :each do
        allow(subject).to receive(:http_client).and_call_original

        WebMock.stub_request(:any, 'http://localhost/v1/test').to_return(
          status: 422,
          headers: {
            'Content-Type' => 'application/json',
          },
          body: {'error' => "You are wrong"}.to_json,
        )
      end

      it "raises StandardError with the server error message" do
        expect{subject.get('test')}.to raise_error(Kontena::Errors::StandardError, /You are wrong/)
      end
    end

    context "with a 422 response with JSON error object" do
      before :each do
        allow(subject).to receive(:http_client).and_call_original

        WebMock.stub_request(:any, 'http://localhost/v1/test').to_return(
          status: 422,
          headers: {
            'Content-Type' => 'application/json',
          },
          body: {'error' => { 'foo' => "Foo was invalid" } }.to_json,
        )
      end

      it "raises StandardError with the server error message" do
        expect{subject.get('test')}.to raise_error(Kontena::Errors::StandardErrorHash, /foo: Foo was invalid/)
      end
    end

    context 'version warning' do
      let(:client) { double(:client) }
      let(:response) { double(:response) }
      let(:cli_version) { Kontena::Cli::VERSION }

      before(:each) do
        allow(subject).to receive(:http_client).and_return(client)
        allow(client).to receive(:request).and_return(response)
        allow(response).to receive(:body).and_return("hello")
        allow(response).to receive(:headers).and_return({})
      end

      it 'warns the user once if server version differs enough from master version' do
        bumped_version = cli_version.split('.')[0] + '.' + (cli_version.split('.')[1].to_i + 1).to_s + '.0' # 1.5.4 --> 1.6.0
        expect(response).to receive(:headers).at_least(:once).and_return({'X-Kontena-Version' => bumped_version})
        expect(subject).to receive(:check_version_and_warn).at_least(:once).and_call_original
        expect(subject).to receive(:add_version_warning).with(bumped_version).once.and_return(true)
        expect(subject.get("test")).to eq 'hello'
        expect(subject.get("test")).to eq 'hello'
      end

      it 'does not warn the user if server version does not differ too much' do
        bumped_version = cli_version.split('.')[0] + '.' + cli_version.split('.')[1] + '.' + (cli_version.split('.')[2].to_i + 1).to_s # 1.5.4 --> 1.5.5
        expect(response).to receive(:headers).at_least(:once).and_return({'X-Kontena-Version' => bumped_version})
        expect(subject).to receive(:check_version_and_warn).at_least(:once).and_call_original
        expect(subject).not_to receive(:at_exit)
        expect(subject).not_to receive(:add_version_warning)
        expect(subject.get("test")).to eq 'hello'
      end

      it 'does not warn the user if server version is not there at all' do
        expect(response).to receive(:headers).at_least(:once).and_return({})
        allow(subject).to receive(:check_version_and_warn).at_least(:once).and_call_original
        expect(subject).not_to receive(:at_exit)
        expect(subject).not_to receive(:add_version_warning)
        expect(subject.get("test")).to eq 'hello'
      end
    end

    context 'user agent' do
      it 'has version and build tags' do
        expect(subject.default_headers['User-Agent']).to match(/^kontena-cli\/\d+\.\d+\.\d+.+?\+ruby.+?\+/)
      end
    end
  end
end

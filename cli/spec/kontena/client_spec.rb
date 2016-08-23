require_relative '../spec_helper'
require 'kontena_cli'
require 'ostruct'

describe Kontena::Client do

  let(:subject) { described_class.new('https://localhost/v1/') }
  let(:http_client) { double(:http_client) }

  # This trickery is here for making the tests work with or without the new configuration handler.
  # The client itself will work with any kind of token that acts like a hash or ostruct.
  let(:server_class)   { Kontena::Cli.const_defined?('Config') ? Kontena::Cli::Config::Server  : OpenStruct }
  let(:token_class)    { Kontena::Cli.const_defined?('Config') ? Kontena::Cli::Config::Token   : OpenStruct }
  let(:account_class)  { Kontena::Cli.const_defined?('Config') ? Kontena::Cli::Config::Account : OpenStruct }

  let(:master) { server_class.new(url: 'https://localhost', name: 'master') }
  let(:token) { token_class.new(access_token: '1234', refresh_token: '5678', expires_at: nil, parent_type: :master, parent: master) }
  let(:expiring_token) { token_class.new(access_token: '1234', refresh_token: '5678', expires_at: Time.now.utc + 1000, parent_type: :master, parent: master) }
  let(:expired_token) { token_class.new(access_token: '1234', refresh_token: '5678', expires_at: Time.now.utc - 1000, parent_type: :master, parent: master) }

  before(:each) do
    allow(subject).to receive(:http_client)
    if Kontena::Cli.const_defined?('Config')
      allow(Kontena::Cli::Config).to receive(:find_server).and_return(master)
      allow(Kontena::Cli::Config).to receive(:current_master).and_return(master)
      allow(Kontena::Cli::Config).to receive(:account).and_return(Kontena::Cli::Config::Account.new(Kontena::Cli::Config.master_account_data))
      allow(Kontena::Cli::Config).to receive(:write).and_return(true)
    end
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
      allow(master).to receive(:token).and_return(expired_token)
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
        hash_including(headers: hash_including(:'Some-Header' => 'value'), method: :get)
      ).and_return(spy(:response, status: 200))
      subject.get('foo', nil, {:'Some-Header' => 'value'})
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
        hash_including(headers: hash_including(:'Some-Header' => 'value'), method: :get)
      ).and_return(spy(:response, status: 200))
      subject.get_stream('foo', response_block, nil, {:'Some-Header' => 'value'})
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
        hash_including(headers: hash_including(:'Some-Header' => 'value'), method: :post)
      ).and_return(spy(:response, status: 200))
      subject.post('foo', data, nil, {:'Some-Header' => 'value'})
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
        hash_including(headers: hash_including(:'Some-Header' => 'value'), method: :put)
      ).and_return(spy(:response, status: 200))
      subject.put('foo', data, nil, {:'Some-Header' => 'value'})
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
        hash_including(headers: hash_including(:'Some-Header' => 'value'), method: :delete)
      ).and_return(spy(:response, status: 200))
      subject.delete('foo', nil, nil, {:'Some-Header' => 'value'})
    end
  end
end

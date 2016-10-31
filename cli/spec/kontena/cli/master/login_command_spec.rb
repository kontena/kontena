require_relative "../../../spec_helper"
require 'kontena/cli/master/login_command'

describe Kontena::Cli::Master::LoginCommand do

  include ClientHelpers

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:config) { double }

  before(:each) do
    allow(subject).to receive(:config).and_return(config)
  end

  describe '#use_current_master_if_available' do
    context 'url not given' do
      it 'sets local url current master url if defined' do
        expect(config).to receive(:current_master).twice.and_return(Kontena::Cli::Config::Server.new(url: 'foo'))
        expect(subject).to receive(:url=).with('foo')
        expect(subject.use_current_master_if_available).to be_truthy
      end

      it 'raises if no current master and no url' do
        subject.url = nil
        expect(config).to receive(:current_master).and_return(nil)
        expect(subject).to receive(:exit_with_error)
        subject.use_current_master_if_available
      end
    end

    context 'url given' do
      it 'returns nil' do
        subject.url = 'foofoo'
        expect(subject.use_current_master_if_available).to be_nil
      end
    end
  end

  describe '#use_master_by_name' do
    context 'url given' do
      it 'should return nil when url looks like an url' do
        subject.url = 'http://foo'
        expect(subject).not_to receive(:config)
        expect(subject.use_master_by_name).to be_nil
      end
    end

    context 'name given' do
      it 'should try to look for servers by name' do
        expect(config).to receive(:find_server).and_return(Kontena::Cli::Config::Server.new(url: 'https://foo'))
        subject.url = 'foomaster'
        expect(subject).to receive(:url=).with('https://foo')
        subject.use_master_by_name
      end
    end
  end

  describe '#find_server_or_create_new' do

    let(:existing_server) { Kontena::Cli::Config::Server.new(url: 'https://foo', name: 'existing') }

    it 'should try to pick up an existing server from config' do
      subject.name = 'name'
      expect(config).to receive(:find_server_by).with(url: 'foo', name: 'name').and_return(existing_server)
      expect(config).to receive(:current_server=).with(existing_server.name)
      expect(subject.find_server_or_create_new('foo')).to eq existing_server
    end

    it 'should create a new server instance if existing not found' do
      expect(config).to receive(:find_server_by).and_return(nil)
      subject.name = "foofoo1"
      servers = []
      expect(config).to receive(:servers).and_return(servers)
      expect(config).to receive(:current_server=).with('foofoo1')
      expect(subject.find_server_or_create_new('http://foo').name).to eq 'foofoo1'
      expect(servers.first.url).to eq 'http://foo'
      expect(servers.first.name).to eq 'foofoo1'
    end
  end

  describe '#set_server_token' do
    let(:server) { Kontena::Cli::Config::Server.new(name: 'some_server') }
    let(:token) { Kontena::Cli::Config::Token.new(access_token: 'bartoken') }

    it 'should set token from parameters as the servers access token' do
      subject.token = 'footoken'
      expect(server).to receive(:token=) do |token|
        expect(token.access_token).to eq 'footoken'
      end
      subject.set_server_token(server)
    end

    it 'should clear servers existing token when forced' do
      subject.force = true
      server.token = token
      subject.set_server_token(server)
      expect(server.access_token).to be_nil
    end

    it 'should add a blank token if server has none' do
      server.token = nil
      subject.set_server_token(server)
      expect(server.access_token).to be_nil
      expect(server.token.parent_name).to eq 'some_server'
    end

    it 'should keep the existing token unless a new one is supplied' do
      server.token = token
      subject.token = nil
      subject.force = false
      subject.set_server_token(server)
      expect(server.token).to eq token
    end
  end

  describe '#use_authorization_code' do
    let(:client) { double }

    before(:each) do
      allow(subject.config).to receive(:current_server=)
    end

    it 'should set the local name to name provided from server if no name was set' do
      expect(Kontena::Client).to receive(:new).and_return(client)
      expect(client).to receive(:exchange_code).with('abcd1234').and_return(
        { 
          'access_token' => 'token',
          'refresh_token' => 'refresh_token',
          'expires_in' => 1000,
          'server' => {
            'name' => 'foofoo1'
          }
        }
      )

      server = Kontena::Cli::Config::Server.new(name: nil, url: 'http://foo')
      subject.use_authorization_code(server, 'abcd1234')
      expect(server.token.access_token).to eq 'token'
      expect(server.name).to eq 'foofoo1'
    end

    it 'should not touch the local name if the server already has a name' do
      expect(Kontena::Client).to receive(:new).and_return(client)
      expect(client).to receive(:exchange_code).with('abcd1234').and_return(
        { 
          'access_token' => 'token',
          'refresh_token' => 'refresh_token',
          'expires_in' => 1000,
          'server' => {
            'name' => 'foofoo1'
          }
        }
      )

      server = Kontena::Cli::Config::Server.new(name: 'foofoo2', url: 'http://foo')
      subject.use_authorization_code(server, 'abcd1234')
      expect((Time.now.utc.to_i+800..Time.now.utc.to_i+1100).cover?(server.token.expires_at.to_i)).to be_truthy
      expect(server.name).to eq 'foofoo2'
    end
  end

  describe '#in_to_at' do
    it 'should return nil when expires_in is <0 or nil' do
      expect(subject.in_to_at(0)).to be_nil
      expect(subject.in_to_at(-1)).to be_nil
      expect(subject.in_to_at(nil)).to be_nil
    end

    it 'should return a timestamp when expires_in is >0' do
      time = Time.now.utc.to_i
      expect((time + 80..time + 120).cover?(subject.in_to_at(100))).to be_truthy
    end
  end

  describe '#update_server_name' do
    let(:server) { Kontena::Cli::Config::Server.new }
    let(:response) { { 'access_token' => 'token', 'server' => { 'name' => 'foo2' } } }

    it 'should do nothing if server already has a name' do
      server.name = 'foofoofoo'
      subject.update_server_name(server, response)
      expect(server.name).to eq 'foofoofoo'
    end

    it 'should set the name from name parameter if set' do
      subject.name = 'abcd'
      subject.update_server_name(server, response)
      expect(server.name).to eq 'abcd'
    end

    it 'should set the name from server response if returned' do
      subject.update_server_name(server, response)
      expect(server.name).to eq 'foo2'
    end

    it 'should use a default name if no other can be figured out' do
      expect(subject.config).to receive(:find_server).with('kontena-master').and_return(nil)
      subject.update_server_name(server, response.reject{|k,v| k=='server'})
      expect(server.name).to eq 'kontena-master'
    end

    it 'should use a default name with suffix if one already exists' do
      expect(subject.config).to receive(:find_server).with('kontena-master').and_return(true)
      expect(subject.config).to receive(:find_server).with('kontena-master-2').and_return(true)
      expect(subject.config).to receive(:find_server).with('kontena-master-3').and_return(nil)
      subject.update_server_name(server, response.reject{|k,v| k=='server'})
      expect(server.name).to eq 'kontena-master-3'
    end

  end

end

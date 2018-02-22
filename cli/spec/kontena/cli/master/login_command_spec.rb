require 'kontena/cli/master/login_command'
require 'kontena/cli/localhost_web_server'
require 'kontena/cli/browser_launcher'
require 'ostruct'

describe Kontena::Cli::Master::LoginCommand do

  include ClientHelpers

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:client) { double(:client) }

  it 'should exit with error if --code and --token both given' do
    expect{subject.run(%w(--code abcd --token defg))}.to exit_with_error
  end

  it 'should exit with error if --code and --join both given' do
    expect{subject.run(%w(--code abcd --join defg))}.to exit_with_error
  end

  it 'should exit with error if --code and --force both given' do
    expect{subject.run(%w(--code abcd --force))}.to exit_with_error
  end

  it 'should exit with error if --token and --force both given' do
    expect{subject.run(%w(--token abcd --force))}.to exit_with_error
  end

  describe '#select_a_server' do
    let(:config) { double(:config) }
    let(:server) { Kontena::Cli::Config::Server.new(url: 'https://foo', name: 'server') }

    before(:each) do
      allow(subject).to receive(:config).and_return(config)
    end

    context 'no url or name provided' do
      it 'tries to use current_master' do
        expect(config).to receive(:current_master).at_least(:once).and_return(server)
        expect(subject.select_a_server(nil, nil)).to eq server
      end

      it 'exits with error if current_master not set' do
        expect(config).to receive(:current_master).and_return(nil)
        expect{subject.select_a_server(nil, nil)}.to exit_with_error
      end
    end

    context 'name provided' do
      context 'with url' do
        it 'should return the existing server if an exact match is found' do
          expect(config).to receive(:find_server_by).and_return(server)
          expect(subject.select_a_server(server.name, server.url)).to be server
        end

        it 'should return the existing one but update its url if a name match is found' do
          allow(config).to receive(:find_server_by).and_return(nil)
          expect(config).to receive(:find_server).and_return(server)
          expect(subject.select_a_server(server.name, 'http://foofoo')).to be server
          expect(server.url).to eq 'http://foofoo'
        end

        it 'should create a new server entry if no exact match or name match is found' do
          allow(config).to receive(:find_server_by).and_return(nil)
          allow(config).to receive(:find_server).and_return(nil)
          new_server = subject.select_a_server('fooserver', 'http://foofoo')
          expect(new_server).not_to be server
          expect(new_server.url).to eq 'http://foofoo'
          expect(new_server.name).to eq 'fooserver'
        end
      end

      context 'without url' do
        it 'should return a server with that name if it has an url' do
          expect(config).to receive(:find_server).with('foo').and_return(server)
          expect(subject.select_a_server('foo', nil)).to be server
          expect(server.url).not_to be_nil
        end

        it 'should exit with error if a server with that name is found but it does not have an url' do
          server.url = nil
          expect(config).to receive(:find_server).with('foo').and_return(server)
          expect{subject.select_a_server('foo', nil)}.to exit_with_error
        end
      end
    end

    context 'url provided without name' do
      context 'url looks like an url' do
        it 'should try to find a server with that url and return it if found' do
          expect(config).to receive(:find_server_by).with({ :url => 'https://foo' }).and_return(server)
          expect(subject.select_a_server(nil, 'https://foo')).to be server
        end

        it 'should create a new server entry if not found' do
          expect(config).to receive(:find_server_by).with({ :url => 'https://foo' }).and_return(nil)
          new_server = subject.select_a_server(nil, 'https://foo')
          expect(new_server).not_to be server
          expect(new_server.url).to eq 'https://foo'
        end
      end

      context 'url looks like a name' do
        it 'should return a server with that name if it has an url' do
          expect(config).to receive(:find_server).with('foo').and_return(server)
          expect(subject.select_a_server(nil, 'foo')).to be server
          expect(server.url).not_to be_nil
        end

        it 'should exit with error if a server with that name is found but it does not have an url' do
          server.url = nil
          expect(config).to receive(:find_server).with('foo').and_return(server)
          expect{subject.select_a_server(nil, 'foo')}.to exit_with_error
        end

        it 'should try to find a cloud master with name' do
          expect(subject).to receive(:cloud_auth?).and_return(true)
          expect(config).to receive(:find_server).with('foo').and_return(nil)
          client_double = double(:cloud_client)
          expect(subject).to receive(:cloud_client).and_return(client_double)
          allow(config).to receive(:find_server_by).with(name: 'foo').and_return(nil)
          expect(client_double).to receive(:get).and_return('data' => [ {'id' => '123', 'attributes' => { 'name' => 'foo', 'url' => 'http://foo' }} ])
          server = subject.select_a_server(nil, 'foo')
          expect(server.url).to eq 'http://foo'
        end

        it 'should exit with error if a server with that name is not found' do
          expect(subject).to receive(:cloud_auth?).and_return(false)
          expect(config).to receive(:find_server).with('foo').and_return(nil)
          expect{subject.select_a_server(nil, 'foo')}.to exit_with_error
        end
      end
    end
  end

  context 'with a server with a token in config' do
    before(:each) do
      allow(File).to receive(:read).and_return('
        {
          "current_server": null,
          "current_account": "kontena",
          "servers": [
            {
              "name": "fooserver",
              "url": "http://foo.example.com:80",
              "username": "admin",
              "grid": "test",
              "token": "abcd",
              "token_expires_at": 0,
              "refresh_token": null
            }
          ]
        }
      ')
      allow(File).to receive(:write).and_return(true)
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:readable?).and_return(true)
      allow(Kontena::Client).to receive(:new).and_return(client)
      allow(Kontena::Cli::BrowserLauncher).to receive(:open).and_return(true)
      allow(Kontena::LocalhostWebServer).to receive(:port).and_return(12345)
      allow(Kontena::LocalhostWebServer).to receive(:serve_one).and_return(
        { 'code' => 'abcd1234' }
      )
    end

    it 'logs in and changes the url of a named server in config' do
      expect(File).to receive(:write) do |fn, content|
        data = JSON.parse(content)
        expect(data['servers'].size).to eq 1
        expect(data['servers'].first['name']).to eq 'fooserver'
        expect(data['servers'].first['url']).to eq 'http://foo2.example.com'
        expect(data['servers'].first['token']).to eq 'abcdefg'
      end.and_return(true)
      expect(subject.config).to receive(:find_server).at_least(:once).with('fooserver').and_call_original
      expect(client).to receive(:authentication_ok?).and_return(true)
      subject.run(%w(--token abcdefg --name fooserver --grid foogrid http://foo2.example.com))
    end

    it 'logs in and creates a new entry in config' do
      expect(File).to receive(:write) do |fn, content|
        data = JSON.parse(content)
        expect(data['servers'].size).to eq 2
        expect(data['servers'].first['name']).to eq 'fooserver'
        expect(data['servers'].first['url']).to eq 'http://foo.example.com:80'
        expect(data['servers'].first['token']).to eq 'abcd'
        expect(data['servers'].last['name']).to eq 'fooserver2'
        expect(data['servers'].last['url']).to eq 'http://foo2.example.com'
        expect(data['servers'].last['token']).to eq 'abcdefg'
      end.and_return(true)
      expect(subject.config).to receive(:find_server).at_least(:once).with('fooserver2').and_call_original
      expect(client).to receive(:authentication_ok?).and_return(true)
      subject.run(%w(--token abcdefg --name fooserver2 --grid foogrid http://foo2.example.com))
    end

    it 'uses the existing token if it works and no --code --token --join or --force set when using url' do
      expect(client).to receive(:authentication_ok?).and_return(true)
      subject.run(%w(http://foo.example.com:80))
      expect(subject.config.servers.size).to eq 1
      expect(subject.config.current_server).to eq 'fooserver'
      expect(subject.config.servers.first.name).to eq 'fooserver'
      expect(subject.config.servers.first.url).to eq 'http://foo.example.com:80'
    end

    it 'uses the existing token if it works and no --code --token --join or --force set when using --name' do
      expect(client).to receive(:authentication_ok?).and_return(true)
      subject.run(%w(--name fooserver))
      expect(subject.config.servers.size).to eq 1
      expect(subject.config.current_server).to eq 'fooserver'
      expect(subject.config.servers.first.name).to eq 'fooserver'
      expect(subject.config.servers.first.url).to eq 'http://foo.example.com:80'
    end

    it 'uses the existing token if it works and no --code --token --join or --force set when using name in url param' do
      expect(client).to receive(:authentication_ok?).and_return(true)
      subject.run(%w(fooserver))
      expect(subject.config.servers.size).to eq 1
      expect(subject.config.current_server).to eq 'fooserver'
      expect(subject.config.servers.first.name).to eq 'fooserver'
      expect(subject.config.servers.first.url).to eq 'http://foo.example.com:80'
    end

    it 'uses current master and its token token if it works and no --code --token --join or --force set when no params' do
      subject.config.current_server = 'fooserver'
      expect(client).to receive(:authentication_ok?).and_return(true)
      subject.run([])
      expect(subject.config.servers.size).to eq 1
      expect(subject.config.current_server).to eq 'fooserver'
      expect(subject.config.servers.first.name).to eq 'fooserver'
      expect(subject.config.servers.first.url).to eq 'http://foo.example.com:80'
    end

    it 'goes to web flow when the existing token does not work' do
      expect(client).to receive(:authentication_ok?).and_return(false)
      expect(subject).to receive(:web_flow).and_return(true)
      subject.run(%w(--no-remote fooserver))
    end
  end

  context 'with no servers in config' do
    let(:webserver) { double(:webserver) }
    before(:each) do
      allow(File).to receive(:read).and_return('
        {
          "current_server": null,
          "current_account": "kontena",
          "servers": []
        }
      ')
      allow(File).to receive(:write).and_return(true)
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:readable?).and_return(true)
      allow(Kontena::Client).to receive(:new).and_return(client)
      allow(Kontena::LocalhostWebServer).to receive(:new).and_return(webserver)
      allow(webserver).to receive(:port).and_return(12345)
      allow(webserver).to receive(:serve_one).and_return(
        { 'code' => 'abcd1234' }
      )
    end

    it 'creates a new entry when successful login using web flow' do
      expect(client).to receive(:last_response).at_least(:once).and_return(OpenStruct.new(status: 302, headers: { 'Location' => 'http://authprovider.example.com/authplz' }))
      expect(client).to receive(:request) do |opts|
        expect(opts[:path]).to eq "/authenticate?redirect_uri=http%3A%2F%2Flocalhost%3A12345%2Fcb&expires_in=7200"
        expect(opts[:http_method]).to eq :get
      end.and_return({})
      expect(Kontena::Cli::BrowserLauncher).to receive(:open).with('http://authprovider.example.com/authplz').and_return(true)
      expect(client).to receive(:exchange_code).with('abcd1234').and_return('access_token' => 'defg456', 'server' => { 'name' => 'foobar' }, 'user' => { 'name' => 'testuser' })
      subject.run(%w(--no-remote --skip-grid-auto-select http://foobar.example.com))
      expect(subject.config.servers.size).to eq 1
      server = subject.config.servers.first
      expect(server.url).to eq 'http://foobar.example.com'
      expect(server.name).to eq 'foobar'
      expect(server.username).to eq 'testuser'
      expect(server.token.access_token).to eq 'defg456'
      expect(server.token.refresh_token).to be_nil
      expect(server.token.expires_at).to be_nil
    end

    it 'creates a new entry when successful login using --code' do
      expect(client).to receive(:exchange_code).with('defg').and_return('access_token' => 'defg456', 'server' => { 'name' => 'foobar' }, 'user' => { 'name' => 'testuser' })
      subject.run(%w(--skip-grid-auto-select --code defg http://foobar.example.com))
      expect(subject.config.servers.size).to eq 1
      server = subject.config.servers.first
      expect(server.url).to eq 'http://foobar.example.com'
      expect(server.name).to eq 'foobar'
      expect(server.username).to eq 'testuser'
      expect(server.token.access_token).to eq 'defg456'
      expect(server.token.refresh_token).to be_nil
      expect(server.token.expires_at).to be_nil
    end

    it 'asks for code when using --remote' do
      expect(client).to receive(:last_response).at_least(:once).and_return(OpenStruct.new(status: 302, headers: { 'Location' => 'http//authprovider.example.com/authplz' }))
      expect(client).to receive(:request) do |opts|
        expect(opts[:path]).to eq "/authenticate?redirect_uri=%2Fcode&expires_in=7200"
        expect(opts[:http_method]).to eq :get
      end.and_return({})
      expect(Kontena.prompt).to receive(:ask).and_return("abcd")
      expect(subject).to receive(:use_authorization_code).and_return('true')
      subject.run(%w(--remote http://foobar.example.com))
    end
  end

  context 'with servers in config' do
    let(:webserver) { double(:webserver) }
    before(:each) do
      allow(File).to receive(:read).and_return('
        {
          "current_server": null,
          "current_account": "kontena",
          "servers": [
            {
              "name": "fooserver",
              "url": "http://foo.example.com:80",
              "username": "admin",
              "grid": "test",
              "token": "abcd",
              "token_expires_at": 0,
              "refresh_token": null
            }
          ]
        }
      ')

      allow(File).to receive(:write).and_return(true)
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:readable?).and_return(true)
      allow(Kontena::Client).to receive(:new).and_return(client)
      allow(Kontena::LocalhostWebServer).to receive(:new).and_return(webserver)
      allow(Kontena).to receive(:browserless?).and_return(false)
      allow(webserver).to receive(:port).and_return(12345)
      allow(webserver).to receive(:serve_one).and_return(
        { 'code' => 'abcd1234' }
      )
    end

    it 'changes current master to created master' do
      allow(client).to receive(:last_response).at_least(:once).and_return(OpenStruct.new(status: 302, headers: { 'Location' => 'http://authprovider.example.com/authplz' }))
      allow(client).to receive(:request).and_return({})
      allow(Kontena::Cli::BrowserLauncher).to receive(:open).with('http://authprovider.example.com/authplz').and_return(true)
      allow(client).to receive(:exchange_code).with('abcd1234').and_return('access_token' => 'defg456', 'server' => { 'name' => 'foobar' }, 'user' => { 'name' => 'testuser' })
      subject.config.current_master = 'fooserver'
      subject.config.current_master
      subject.run(%w(--no-remote --skip-grid-auto-select http://foobar.example.com))
      expect(subject.config.current_master.name).to eq 'foobar'
    end
  end

  describe '#authentication_url_from_master' do
    it 'should exit with error if master returns a json with error' do
      allow(Kontena::Client).to receive(:new).and_return(client)
      expect(client).to receive(:last_response).at_least(:once).and_return(OpenStruct.new(status: 400, headers: {}))
      expect(client).to receive(:request).and_return('error' => 'no good')
      expect{subject.authentication_url_from_master('https://foo.example.com', remote: true)}.to exit_with_error
    end

    it 'should exit with error if master returns text' do
      allow(Kontena::Client).to receive(:new).and_return(client)
      expect(client).to receive(:last_response).at_least(:once).and_return(OpenStruct.new(status: 400, headers: {}))
      expect(client).to receive(:request).and_return('Fail!')
      expect{subject.authentication_url_from_master('https://foo.example.com', remote: true)}.to exit_with_error
    end

    it 'should exit with error if master returns nil' do
      allow(Kontena::Client).to receive(:new).and_return(client)
      expect(client).to receive(:last_response).at_least(:once).and_return(OpenStruct.new(status: 400, headers: {}))
      expect(client).to receive(:request).and_return(nil)
      expect{subject.authentication_url_from_master('https://foo.example.com', remote: true)}.to exit_with_error
    end
  end

  describe '#display_remote_message' do
    it 'should only print out the url if --silent' do
      subject.silent = true
      server = Kontena::Cli::Config::Server.new(url: 'https://foo', name: 'server')
      expect(subject).to receive(:authentication_url_from_master).and_return('http://foo')
      expect{subject.display_remote_message(server, {})}.to output("http://foo\n").to_stdout
    end
  end

  describe '#authentication_path' do
    it 'should raise if not doing --remote and the local port is missing' do
      expect{subject.authentication_path(local_port: nil, remote: false)}.to raise_error(ArgumentError)
    end
  end

  describe '#update_server_token' do
    let(:server) { Kontena::Cli::Config::Server.new(url: 'https://foo', name: 'server') }

    it 'should raise unless response is a hash' do
      expect{subject.update_server_token(server, nil)}.to raise_error(TypeError)
    end

    it 'should do a code exchange if response has "code"' do
      expect(subject).to receive(:use_authorization_code).with(server, "abcd")
      subject.update_server_token(server, "code" => "abcd")
    end

    it 'should exit with error if response has error' do
      expect{subject.update_server_token(server, "error" => "abcd")}.to exit_with_error
    end

    it 'should update the token if all is good' do
      subject.update_server_token(server, 'access_token' => 'abcd1234', 'refresh_token' => 'defg', 'expires_at' => 1234)
      expect(server.token.access_token).to eq 'abcd1234'
      expect(server.token.refresh_token).to eq 'defg'
      expect(server.token.expires_at).to eq 1234
    end
  end

  describe '#update_server_name' do
    let(:server) { Kontena::Cli::Config::Server.new(url: 'https://foo', name: nil) }

    it 'should use a default name if response has no name' do
      subject.update_server_name(server, "foo" => "foofoo")
      expect(server.name).to eq 'kontena-master'
    end

    it 'should not mess with the server name if it already has one' do
      server.name = 'foofoo'
      subject.update_server_name(server, "server" => { "name" => "barbar" })
      expect(server.name).to eq 'foofoo'
    end
  end
end

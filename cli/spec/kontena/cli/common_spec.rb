require "kontena/cli/common"

describe Kontena::Cli::Common do
  let(:subject) do
    Class.new do
      include Kontena::Cli::Common
    end.new
  end

  before(:each) do
    RSpec::Mocks.space.proxy_for(File).reset
    Kontena::Cli::Config.reset_instance
  end

  def mock_config(cfg_hash)
    expect(File).to receive(:readable?).and_return(true)
    expect(File).to receive(:exist?).and_return(true)
    expect(File).to receive(:read).and_return(cfg_hash.to_json)
  end

  describe '#current_grid' do
    it 'returns nil by default' do
      mock_config({
        'current_server' => 'alias',
        'servers' => [
           {'name' => 'some_master', 'url' => 'some_master'},
           {'name' => 'alias', 'url' => 'someurl'}
        ]
      })

      expect(subject.current_grid).to eq(nil)
    end

    it 'returns grid from env' do
      allow(ENV).to receive(:[]).with(anything).and_return(nil)
      allow(ENV).to receive(:[]).with('DEBUG').and_call_original
      allow(ENV).to receive(:[]).with('KONTENA_GRID').and_return('foo')
      expect(subject.current_grid).to eq('foo')
    end

    it 'returns grid from json' do
      mock_config({
        'current_server' => 'alias',
        'servers' => [
          {'name' => 'some_master', 'url' => 'some_master'},
          {'name' => 'alias', 'url' => 'someurl', 'grid' => 'foo_grid'}
        ]
      })
      expect(subject.current_grid).to eq('foo_grid')
    end

    it 'returns nil if settings are not present' do
      allow(subject).to receive(:current_master).and_raise(ArgumentError)
      expect(subject.current_grid).to be_nil
    end
  end

  describe '#api_url' do
    it 'raises error by default' do
      expect {
        subject.api_url
      }.to raise_error(ArgumentError)
    end

    it 'return url from env' do
      allow(ENV).to receive(:[]).with(anything).and_return(nil)
      allow(ENV).to receive(:[]).with('KONTENA_URL').and_return('https://domain.com')
      expect(subject.api_url).to eq('https://domain.com')
    end
  end

  describe '#require_token' do
    it 'raises error by default' do
      expect {
        subject.require_token
      }.to raise_error(ArgumentError)
    end
  end

  describe '#current_master' do
    it 'return correct master info' do
      mock_config({
        'current_server' => 'alias',
        'servers' => [
          {'name' => 'some_master', 'url' => 'some_master'},
          {'name' => 'alias', 'url' => 'someurl'}
        ]
      })
      expect(subject.current_master['url']).to eq('someurl')
      expect(subject.current_master['name']).to eq('alias')
    end
  end

  describe '#settings' do
    it 'migrates old settings' do
      mock_config({
        "server" => {
          "url" => "https://master.domain.com:8443",
          "grid" => "my-grid",
          "token" => "kontena-token"
        }
      })
      expect(File).to receive(:write) do |filename, content|
        expect(File.basename(filename)).to eq(".kontena_client.json")
        config_hash = JSON.parse(content)
        expect(config_hash['servers']).to be_kind_of(Array)
        expect(config_hash['servers'].first).to be_kind_of(Hash)
        expect(config_hash['servers'].first['name']).to eq("default")
        expect(config_hash['servers'].first['url']).to eq("https://master.domain.com:8443")
        expect(config_hash['servers'].first['token']).to eq("kontena-token")
        expect(config_hash['servers'].first['grid']).to eq("my-grid")
        expect(config_hash['current_server']).to be_kind_of(String)
        expect(config_hash['current_server']).to eq("default")
      end
      subject.config.write
    end

  end

  describe '#error' do
    it 'prints error message to stderr if given and raise error' do
      begin
        expect{subject.error('error message!')}.to output('error message').to_stderr
      rescue SystemExit => ex
        expect(ex.status).to be 1
      end
    end
  end

  context 'confirm' do
    before(:each) do
      expect($stdout).to receive(:tty?).at_least(:once).and_return(true)
      expect($stdin).to receive(:tty?).at_least(:once).and_return(true)
    end

    describe '#confirm_command' do
      it 'returns true if input matches' do
        allow(subject).to receive(:ask).and_return('name-to-confirm')

        expect(subject.confirm_command('name-to-confirm')).to be_truthy
        expect{subject.confirm_command('name-to-confirm')}.to_not raise_error
      end

      it 'raises error unless input matches' do
        expect(subject).to receive(:ask).and_return('wrong-name')
        expect(subject).to receive(:error).with(/did not match/)

        subject.confirm_command('name-to-confirm')
      end
    end

    describe '#confirm' do
      it 'returns true if confirmed' do
        allow(subject.prompt).to receive(:yes?).and_return(true)

        expect(subject.confirm).to be_truthy
        expect{subject.confirm}.to_not raise_error
      end

      it 'raises error unless confirmed' do
        expect(subject.prompt).to receive(:yes?).and_return(false)
        expect(subject).to receive(:error).with(/Aborted/)

        subject.confirm
      end
    end
  end

  describe '#use_refresh_token' do
    let(:server) do
      spy
    end

    let(:token) do
      token = double
      allow(server).to receive(:token).and_return(token)
      token
    end

    let(:client) do
      spy
    end

    it 'returns nil if token is nil' do
      allow(server).to receive(:token).and_return(nil)
      expect(subject.use_refresh_token(server)).to be_nil
    end

    it 'returns nil if refresh_token is nil' do
      expect(token).to receive(:refresh_token).and_return nil
      expect(subject.use_refresh_token(server)).to be_nil
    end

    context 'with valid token' do
      before(:each) do
        allow(token).to receive(:refresh_token).and_return 'refresh_token'
        allow(token).to receive(:expired?).and_return false
      end

      it 'returns nil if token is expired' do
        expect(token).to receive(:expired?).and_return true
        expect(subject.use_refresh_token(server)).to be_nil
      end

      it 'creates refresh_token request to given server' do
        allow(server).to receive(:url).and_return('http://www.example.org')
        expect(Kontena::Client).to receive(:new).with('http://www.example.org', token).and_return(client)
        expect(client).to receive(:refresh_token).once
        subject.use_refresh_token(server)
      end
    end
  end
end

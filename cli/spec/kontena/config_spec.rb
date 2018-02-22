
# Lots of coverage already in Common spec
describe Kontena::Cli::Config do

  let(:subject) { described_class.instance }

  context 'base' do
    before(:each) do
      allow(File).to receive(:exist?).and_return(false)
      allow(File).to receive(:write).and_return(true)
      subject.class.reset_instance
      subject.servers << Kontena::Cli::Config::Server.new(
        url: 'http://localhost',
        name: 'test',
        token: Kontena::Cli::Config::Token.new(access_token: 'abcd')
      )
    end

    it 'finds a server by name' do
      expect(subject.find_server('test').url).to eq 'http://localhost'
    end

    it 'finds a server by url' do
      expect(subject.find_server_by(url: 'http://localhost').name).to eq 'test'
    end

    it 'returns current master' do
      subject.current_master = 'test'
      expect(subject.current_master.name).to eq 'test'
    end

    it 'returns an array of servers' do
      expect(subject.servers).to be_kind_of(Array)
      expect(subject.servers.first.url).to match /^http/
    end

    it 'returns an array of accounts' do
      expect(subject.accounts).to be_kind_of(Array)
    end

    it 'adds default accounts' do
      expect(subject.find_account('kontena').name).to eq 'kontena'
      expect(subject.find_account('master').name).to eq 'master'
    end

    it 'sets and returns current grid' do
      subject.current_master = 'test'
      subject.current_grid = 'foo'
      expect(subject.current_master.grid).to eq 'foo'
      expect(subject.current_grid).to eq 'foo'
    end
  end

  context 'duplicates' do
    before(:each) do
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:readable?).and_return(true)
      allow(File).to receive(:write).and_return(true)
      allow(File).to receive(:read).and_return <<-EOB
        {"current_server": "test123",
          "servers" : [
            {
              "name": "test123",
              "url": "https://foo.example.com"
            },
            {
              "name": "test123",
              "url": "https://foo2.example.com"
            }
          ]
        }
      EOB

      subject.class.reset_instance
    end

    it 'renames duplicate entries on load' do
      puts subject.servers.inspect
      expect(subject.servers.size).to eq 2
      expect(subject.servers.first.name).not_to eq subject.servers.last.name
      expect(subject.servers.last.name).to eq "test123-2"
    end
  end

  context 'environment variables' do
    it 'sets cloud account on KONTENA_CLOUD_TOKEN' do
      allow(ENV).to receive(:[]).with('KONTENA_CLOUD_TOKEN').and_return('abc')
      expect(subject.current_account.token.access_token).to eq('abc')
    end

    it 'sets master information on KONTENA_URL, KONTENA_TOKEN & KONTENA_GRID' do
      allow(ENV).to receive(:[]).with('KONTENA_URL').and_return('http://localhost')
      allow(ENV).to receive(:[]).with('KONTENA_TOKEN').and_return('abc')
      allow(ENV).to receive(:[]).with('KONTENA_GRID').and_return('test')
      expect(subject.current_master.url).to eq('http://localhost')
      expect(subject.current_master.grid).to eq('test')
    end
  end

  describe 'Token' do
    let(:subject) { Kontena::Cli::Config::Token.new(access_token: 'abcd', expires_at: Time.now.utc - 100) }

    it 'knows when a token is expired' do
      expect(subject.expired?).to be_truthy
      subject.expires_at = Time.now.utc + 100
      expect(subject.expired?).to be_falsey
    end
  end
end


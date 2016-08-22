require_relative '../spec_helper'

# Lots of coverage already in Common spec
describe Kontena::Cli::Config do

  context 'base' do
    let(:subject) { described_class.instance }

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

  describe 'Token' do
    let(:subject) { Kontena::Cli::Config::Token.new(access_token: 'abcd', expires_at: Time.now.utc - 100) }

    it 'knows when a token is expired' do
      expect(subject.expired?).to be_truthy
      subject.expires_at = Time.now.utc + 100
      expect(subject.expired?).to be_falsey
    end
  end
end


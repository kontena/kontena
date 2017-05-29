module ClientHelpers

  def self.included(base)
    base.let(:subject) do
      described_class.new(File.basename($0))
    end

    base.let(:client) do
      instance_double(Kontena::Client, :client)
    end

    base.let(:token) do
      '1234567'
    end

    base.let(:current_grid) do
      'test-grid'
    end

    base.let(:settings) do
      {'current_server' => 'alias',
       'current_account' => 'kontena',
       'servers' => [
           {'name' => 'some_master', 'url' => 'http://someurl.example.com'},
           {'name' => 'alias', 'url' => 'http://someurl.example.com/', 'token' => token, 'account' => 'master', 'grid' => current_grid},
       ]
      }
    end

    base.before(:each) do
      RSpec::Mocks.space.proxy_for(File).reset
      allow(subject).to receive(:client).and_return(client)
      allow(subject).to receive(:current_grid).and_return(current_grid)
      allow(File).to receive(:exist?).with(File.join(Dir.home, '.kontena/certs/someurl.example.com.pem')).and_return(false)
      allow(File).to receive(:exist?).with(File.join(Dir.home, '.kontena_client.json')).and_return(true)
      allow(File).to receive(:readable?).with(File.join(Dir.home, '.kontena_client.json')).and_return(true)
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(File.join(Dir.home, '.kontena_client.json')).and_return(JSON.dump(settings))
      Kontena::Cli::Config.reset_instance
    end
  end

end

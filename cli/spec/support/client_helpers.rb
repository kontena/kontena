module ClientHelpers

  def self.included(base)
    base.let(:subject) do
      described_class.new(File.basename($0))
    end

    base.let(:client) do
      spy(:client)
    end

    base.let(:token) do
      '1234567'
    end

    base.let(:settings) do
      {'current_server' => 'alias',
       'servers' => [
           {'name' => 'some_master', 'url' => 'some_master'},
           {'name' => 'alias', 'url' => 'someurl', 'token' => token}
       ]
      }
    end

    base.before(:each) do
      allow(subject).to receive(:client).with(token).and_return(client)
      allow(subject).to receive(:current_grid).and_return('test-grid')
      allow(subject).to receive(:settings).and_return(settings)
    end
  end
end

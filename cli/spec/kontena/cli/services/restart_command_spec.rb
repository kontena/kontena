require_relative "../../../spec_helper"
require "kontena/cli/services/restart_command"

describe Kontena::Cli::Services::RestartCommand do

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:client) do
    double
  end

  let(:token) do
    '1234567'
  end

  let(:settings) do
    {'current_server' => 'alias',
     'servers' => [
         {'name' => 'some_master', 'url' => 'some_master'},
         {'name' => 'alias', 'url' => 'someurl', 'token' => token}
     ]
    }
  end

  describe '#execute' do

    before(:each) do
      allow(subject).to receive(:client).with(token).and_return(client)
      allow(subject).to receive(:current_grid).and_return('test-grid')
      allow(subject).to receive(:settings).and_return(settings)
      allow(subject).to receive(:restart_service).and_return({})
    end

    it 'requires api url' do
      expect(subject).to receive(:require_api_url).once
      subject.run(['service'])
    end

    it 'requires token' do
      expect(subject).to receive(:require_token).once
      subject.run(['service'])
    end

    it 'triggers restart command' do
      expect(subject).to receive(:restart_service).with(token, 'service')
      subject.run(['service'])
    end
  end
end

require_relative "../../spec_helper"
require "kontena/cli/login_command"

describe Kontena::Cli::LoginCommand do
  describe '#register' do

    let(:settings) do
      {'current_server' => 'alias',
       'servers' => [
           {'name' => 'some_master', 'url' => 'some_master'},
           {'name' => 'alias', 'url' => 'someurl', 'token' => '123456'}
       ]
      }
    end

    let(:auth_client) do
      double(Kontena::Client)
    end

    let(:subject) { described_class.new(File.basename($0)) }

    it 'asks email and password' do
      allow(subject).to receive(:settings).and_return(settings)
      expect(subject).to receive(:ask).once.with('Email: ').and_return('john.doe@acme.io')
      allow(subject).to receive(:ask).once.with('Password: ').and_return('secret')
      allow(Kontena::Client).to receive(:new).and_return(auth_client)
      allow(auth_client).to receive(:post)
      allow(subject).to receive(:request_server_info).and_return(true)
      subject.run(['http://localhost:8443'])
    end
  end
end

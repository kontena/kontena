require_relative "../../../../spec_helper"
require 'kontena/cli/master/users_command'
require 'kontena/cli/master/users/invite_command'

describe Kontena::Cli::Master::Users::InviteCommand do

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:valid_settings) do
    {'current_server' => 'alias',
     'servers' => [
         {'name' => 'some_master', 'url' => 'some_master'},
         {'name' => 'alias', 'url' => 'someurl', 'token' => '123456'}
     ]
    }
  end

  let(:client) { spy(:client) }

  describe "#invite" do
    before(:each) do
      allow(subject).to receive(:client).and_return(client)
      allow(subject).to receive(:settings).and_return(valid_settings)
    end

    it 'makes invitation request for all given users' do
      expect(client).to receive(:post).with("users", {email: 'john@example.org'}).once
      expect(client).to receive(:post).with("users", {email: 'jane@example.org'}).once

      subject.run(['john@example.org', 'jane@example.org'])
    end
  end
end

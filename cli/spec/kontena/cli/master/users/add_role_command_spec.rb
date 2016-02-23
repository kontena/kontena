require_relative "../../../../spec_helper"
require 'kontena/cli/master/users_command'
require 'kontena/cli/master/users/add_role_command'

describe Kontena::Cli::Master::Users::AddRoleCommand do

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:client) { spy(:client) }

  let(:valid_settings) do
    {'current_server' => 'alias',
     'servers' => [
         {'name' => 'some_master', 'url' => 'some_master'},
         {'name' => 'alias', 'url' => 'someurl', 'token' => '123456'}
     ]
    }
  end

  describe "#add-role" do
    before(:each) do
      allow(subject).to receive(:client).and_return(client)
      allow(subject).to receive(:settings).and_return(valid_settings)
    end

    it 'makes add role request for all given users' do
      expect(client).to receive(:post).with("users/john@example.org/roles", {role: 'role'}).once
      expect(client).to receive(:post).with("users/jane@example.org/roles", {role: 'role'}).once

      subject.run(['role', 'john@example.org', 'jane@example.org'])
    end
  end
end

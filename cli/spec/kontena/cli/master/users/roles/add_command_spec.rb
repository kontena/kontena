require 'kontena/cli/master/users_command'
require 'kontena/cli/master/users/roles/add_command'

describe Kontena::Cli::Master::Users::Roles::AddCommand do

  include ClientHelpers

  let(:subject) do
    described_class.new(File.basename($0))
  end

  describe "#add-role" do
    it 'makes add role request for all given users' do
      expect(client).to receive(:post).with("users/john@example.org/roles", {role: 'role'}).once
      expect(client).to receive(:post).with("users/jane@example.org/roles", {role: 'role'}).once

      subject.run(['role', 'john@example.org', 'jane@example.org'])
    end
  end
end

require 'kontena/cli/master/users_command'
require 'kontena/cli/master/users/roles/remove_command'

describe Kontena::Cli::Master::Users::Roles::RemoveCommand do

  include ClientHelpers

  let(:subject) do
    described_class.new(File.basename($0))
  end

  describe "#remove-role" do
    before(:each) do
      allow(subject).to receive(:confirm).and_return(true)
    end

    it 'makes remove role request for all given users' do
      expect(client).to receive(:delete).with("users/john@example.org/roles/role").once
      expect(client).to receive(:delete).with("users/jane@example.org/roles/role").once
      expect(subject).to receive(:confirm).once

      subject.run(['role', 'john@example.org', 'jane@example.org'])
    end
  end
end

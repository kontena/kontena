require 'kontena/cli/master/users_command'
require "kontena/cli/master/users/remove_command"

describe Kontena::Cli::Master::Users::RemoveCommand do

  include ClientHelpers

  describe '#execute' do

    before(:each) do
      allow(subject).to receive(:confirm).and_return(true)
    end

    it 'it requires confirmation' do
      expect(subject).to receive(:confirm).once
      expect(client).to receive(:delete).with('users/john@domain.com')
      subject.run(['john@domain.com'])
    end

    it 'sends email to master' do
      expect(client).to receive(:delete).with('users/john@domain.com')
      subject.run(['john@domain.com'])
    end
  end
end

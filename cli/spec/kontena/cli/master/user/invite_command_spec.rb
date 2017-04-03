require 'kontena/cli/master/user_command'
require 'kontena/cli/master/user/invite_command'

describe Kontena::Cli::Master::User::InviteCommand do

  include ClientHelpers

  describe "#invite" do
    it 'makes invitation request for all given users' do
      expect(client).to receive(:post).with("/oauth2/authorize", {email: 'john@example.org', external_id: nil, response_type: "invite"}).once
      expect(client).to receive(:post).with("/oauth2/authorize", {email: 'jane@example.org', external_id: nil, response_type: "invite"}).once

      subject.run(['john@example.org', 'jane@example.org'])
    end
  end
end

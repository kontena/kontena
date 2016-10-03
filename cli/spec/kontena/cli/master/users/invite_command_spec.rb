require_relative "../../../../spec_helper"
require 'kontena/cli/master/users_command'
require 'kontena/cli/master/users/invite_command'

describe Kontena::Cli::Master::Users::InviteCommand do

  include ClientHelpers

  let(:subject) do
    described_class.new(File.basename($0))
  end

  describe "#invite" do
    it 'makes invitation request for all given users' do
      expect(client).to receive(:post).with("users", {email: 'john@example.org'}).once
      expect(client).to receive(:post).with("users", {email: 'jane@example.org'}).once

      subject.run(['john@example.org', 'jane@example.org'])
    end
  end
end

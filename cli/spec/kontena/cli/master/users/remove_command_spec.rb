require_relative "../../../../spec_helper"
require 'kontena/cli/master/users_command'
require "kontena/cli/master/users/remove_command"

describe Kontena::Cli::Master::Users::RemoveCommand do

  include ClientHelpers

  describe '#execute' do

    it 'requires api url' do
      expect(subject).to receive(:require_api_url).once
      subject.run(['john@domain.com'])
    end

    it 'requires token' do
      expect(subject).to receive(:require_token).and_return(token)
      subject.run(['john@domain.com'])
    end

    it 'sends email to master' do
      expect(client).to receive(:delete).with(
        'users/john@domain.com'
      )
      subject.run(['john@domain.com'])
    end
  end
end

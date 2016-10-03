require_relative "../../../spec_helper"
require "kontena/cli/services/restart_command"

describe Kontena::Cli::Services::RestartCommand do

  include ClientHelpers

  describe '#execute' do

    before(:each) do
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
      expect(subject).to receive(:restart_service)
      subject.run(['service'])
    end
  end
end

require_relative "../../../spec_helper"
require "kontena/cli/stacks/deploy_command"

describe Kontena::Cli::Stacks::DeployCommand do

  include ClientHelpers

  describe '#execute' do
    it 'requires api url' do
      expect(subject).to receive(:require_api_url).once
      subject.run(['test-stack'])
    end

    it 'requires token' do
      expect(subject).to receive(:require_token).and_return(token)
      subject.run(['test-stack'])
    end

    it 'sends deploy command to master' do
      expect(client).to receive(:post).with(
        'stacks/test-grid/test-stack/deploy', {}
      )
      subject.run(['test-stack'])
    end
  end
end

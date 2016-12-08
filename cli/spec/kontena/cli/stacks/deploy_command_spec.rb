require_relative "../../../spec_helper"
require "kontena/cli/stacks/deploy_command"

describe Kontena::Cli::Stacks::DeployCommand do

  include ClientHelpers

  describe '#execute' do
    before(:each) do
      allow(subject).to receive(:wait_for_deploy_to_finish).and_return(spy)
    end

    it 'requires api url' do
      expect(described_class.requires_current_master?).to be_truthy
      subject.run(['test-stack'])
    end

    it 'requires token' do
      expect(described_class.requires_current_master_token?).to be_truthy
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

require_relative "../../../spec_helper"
require "kontena/cli/stacks/deploy_command"

describe Kontena::Cli::Stacks::DeployCommand do

  include ClientHelpers

  describe '#execute' do
    before(:each) do
      allow(subject).to receive(:wait_for_deployment_to_start)
      allow(subject).to receive(:wait_for_deploy_to_finish)
    end

    it 'sends deploy command to master' do
      expect(client).to receive(:post).with('stacks/test-grid/test-stack/deploy', {}).and_return(double())

      subject.run(['test-stack'])
    end
  end
end

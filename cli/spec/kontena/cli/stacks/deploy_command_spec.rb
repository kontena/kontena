require "kontena/cli/stacks/deploy_command"

describe Kontena::Cli::Stacks::DeployCommand do

  include ClientHelpers
  include RequirementsHelper

  expect_to_require_current_master
  expect_to_require_current_master_token

  mock_current_master

  describe '#execute' do
    before(:each) do
      allow(subject).to receive(:wait_for_deploy_to_finish).and_return(true)
      allow(subject).to receive(:wait_for_deployment_to_start).and_return(true)
      allow(subject).to receive(:wait_for_service_deploy).and_return(true)
    end

    it 'sends deploy command to master' do
      expect(client).to receive(:post).with(
        'stacks/test-grid/test-stack/deploy', {}
      ).and_return({})
      subject.run(['test-stack'])
    end
  end
end

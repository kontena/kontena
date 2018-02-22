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

  it 'exits with error if the stack deploy fails to start' do
    expect(client).to receive(:post).with('stacks/test-grid/test-stack/deploy', {}).once.and_return({
        'id' => '59524bd753caed000801b6a3',
        'stack_id' => 'test-grid/test-stack',
        'created_at' => '2017-06-27T12:13:11.181Z',
        'state' => 'created',
        'service_deploys' => [],
    })

    expect(client).to receive(:get).with('stacks/test-grid/test-stack/deploys/59524bd753caed000801b6a3').once.and_return({
        'id' => '59524bd753caed000801b6a3',
        'stack_id' => 'test-grid/test-stack',
        'created_at' => '2017-06-27T12:13:11.181Z',
        'state' => 'error',
        'service_deploys' => [],
    })
    expect(subject).to receive(:sleep).once

    expect{subject.run(['test-stack'])}.to exit_with_error.and output(/Stack deploy failed/).to_stdout
  end
end

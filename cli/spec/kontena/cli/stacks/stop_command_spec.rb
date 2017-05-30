require "kontena/cli/stacks/stop_command"

describe Kontena::Cli::Stacks::StopCommand do
  include ClientHelpers
  include RequirementsHelper

  expect_to_require_current_master
  expect_to_require_current_master_token

  describe '#execute' do
    it 'sends stop request to server' do
      expect(client).to receive(:post).with('stacks/test-grid/foo/stop', {})
      subject.run(['foo'])
    end
  end
end

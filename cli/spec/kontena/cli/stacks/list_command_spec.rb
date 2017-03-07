require "kontena/cli/stacks/list_command"

describe Kontena::Cli::Stacks::ListCommand do
  include ClientHelpers
  include RequirementsHelper

  expect_to_require_current_master
  expect_to_require_current_master_token

  describe '#execute' do
    it 'fetches stacks from master' do
      stacks = {
        'stacks' => []
      }
      expect(client).to receive(:get).with('grids/test-grid/stacks').and_return(stacks)
      subject.run([])
    end
  end
end

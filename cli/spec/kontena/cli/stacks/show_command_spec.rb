require "kontena/cli/stacks/show_command"

describe Kontena::Cli::Stacks::ShowCommand do

  include ClientHelpers

  describe '#execute' do
    it 'fetches stack info from master' do
      expect(client).to receive(:get).with('stacks/test-grid/test-stack').and_return(spy())
      subject.run(['test-stack'])
    end
  end
end

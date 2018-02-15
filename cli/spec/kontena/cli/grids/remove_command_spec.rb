require 'kontena/cli/grids/remove_command'

describe Kontena::Cli::Grids::RemoveCommand do
  include ClientHelpers

  before do
    # Kontena::Cli::Grids::Common#grids
    allow(client).to receive(:get).with('grids').and_return('grids' => grids)
  end

  context 'without any grids' do
    let(:grids) { [] }

    it 'errors out' do
      expect{subject.run ['--force', 'test-grid']}.to exit_with_error.and output(/Could not resolve grid by name/).to_stderr
    end
  end

  context 'with a grid' do
    let(:grids) { [{'id' => 'test-grid', 'name' => 'test-grid'}] }

    it 'deletes the grid' do
      expect(client).to receive(:delete).with('grids/test-grid')

      subject.run ['--force', 'test-grid']
    end
  end
end

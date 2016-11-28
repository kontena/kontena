require_relative "../../../spec_helper"
require "kontena/cli/stacks/show_command"

describe Kontena::Cli::Stacks::ShowCommand do

  include ClientHelpers

  describe '#execute' do
    it 'requires api url' do
      allow(subject).to receive(:forced?).and_return(true)
      expect(described_class.requires_current_master?).to be_truthy
      subject.run(['test-stack'])
    end

    it 'requires token' do
      allow(subject).to receive(:forced?).and_return(true)
      expect(described_class.requires_current_master_token?).to be_truthy
      subject.run(['test-stack'])
    end

    it 'fetches stack info from master' do
      expect(client).to receive(:get).with('stacks/test-grid/test-stack')
      subject.run(['test-stack'])
    end
  end
end

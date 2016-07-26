require_relative "../../../spec_helper"
require "kontena/cli/stacks/show_command"

describe Kontena::Cli::Stacks::ShowCommand do

  include ClientHelpers

  describe '#execute' do
    it 'requires api url' do
      allow(subject).to receive(:forced?).and_return(true)
      expect(subject).to receive(:require_api_url).once
      subject.run(['test-stack'])
    end

    it 'requires token' do
      allow(subject).to receive(:forced?).and_return(true)
      expect(subject).to receive(:require_token).and_return(token)
      subject.run(['test-stack'])
    end

    it 'fetches stack info from master' do
      expect(client).to receive(:get).with('stacks/test-grid/test-stack')
      subject.run(['test-stack'])
    end
  end
end

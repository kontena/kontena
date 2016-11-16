require_relative "../../../spec_helper"
require "kontena/cli/stacks/remove_command"

describe Kontena::Cli::Stacks::RemoveCommand do

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

    it 'sends remove command to master' do
      allow(subject).to receive(:forced?).and_return(true)
      expect(client).to receive(:delete).with('stacks/test-grid/test-stack')
      subject.run(['--force', 'test-stack'])
    end
  end
end

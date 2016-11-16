require_relative "../../../spec_helper"
require "kontena/cli/stacks/list_command"

describe Kontena::Cli::Stacks::ListCommand do

  include ClientHelpers

  describe '#execute' do
    it 'requires api url' do
      expect(subject).to receive(:require_api_url).once
      subject.run([])
    end

    it 'requires token' do
      expect(subject).to receive(:require_token).and_return(token)
      subject.run([])
    end

    it 'fetches stacks from master' do
      stacks = {
        'stacks' => []
      }
      expect(client).to receive(:get).with('grids/test-grid/stacks').and_return(stacks)
      subject.run([])
    end
  end
end

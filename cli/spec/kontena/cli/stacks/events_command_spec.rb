require_relative "../../../spec_helper"
require "kontena/cli/stacks/events_command"

describe Kontena::Cli::Stacks::EventsCommand do

  include ClientHelpers

  describe '#execute' do
    before(:each) do
      allow(client).to receive(:get).and_return({
        'logs' => []
      })
    end

    it 'requests logs from master' do
      expect(client).to receive(:get).with(
        'stacks/test-grid/redish/event_logs', {limit: 100}
      )
      subject.run(['redish'])
    end
  end
end

require 'kontena/cli/grids/events_command'

describe Kontena::Cli::Grids::EventsCommand do
  include ClientHelpers
  include OutputHelpers

  describe '#execute' do
    it 'requests events from master' do
      expect(client).to receive(:get).with(
        'grids/test-grid/event_logs', {limit: 100}
      ).and_return({'logs' => []})
      subject.run([])
    end
  end
end

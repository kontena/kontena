require_relative "../../../spec_helper"
require "kontena/cli/services/events_command"

describe Kontena::Cli::Services::EventsCommand do

  include ClientHelpers

  describe '#execute' do
    before(:each) do
      allow(client).to receive(:get).and_return({
        'logs' => []
      })
    end

    it 'requests logs from master' do
      expect(client).to receive(:get).with(
        'services/test-grid/null/service-a/event_logs', {limit: 100}
      )
      subject.run(['service-a'])
    end

    context 'when passing instance option ' do
      it 'adds it to query params' do
        expect(client).to receive(:get).with(
          'services/test-grid/null/service-a/event_logs', {instance: '1', limit: 100}
        )
        subject.run(['-i', '1', 'service-a'])
      end
    end
  end
end

require_relative '../../spec_helper'
require_relative '../../../app/services/event_stream/grid_event_notifier'

module EventStream
  describe GridEventNotifier do
    before(:each) { Celluloid.boot }
    after(:each) { Celluloid.shutdown }

    subject{klass.new}

    let(:klass) { Class.new { include GridEventNotifier } }

    let(:grid) { Grid.create! }
    let(:client) {spy(:client)}


    describe '#trigger_grid_event' do
      it 'sends event to subscribers' do
        messages = []
        channel = "grids/#{grid.name}"
        listener = MongoPubsub.subscribe(channel) do |msg|
          client.receive(msg)
          messages << msg
        end
        expect(client).to receive(:receive).once.with({'event_type' => 'grid', 'action' => 'update', 'payload' => {}})
        subject.trigger_grid_event(grid, 'grid', 'update', {})
        Timeout::timeout(1) do
          sleep 0.01 until messages.size == 1
        end
        listener.terminate
      end

    end
  end
end
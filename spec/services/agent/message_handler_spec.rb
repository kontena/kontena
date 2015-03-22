require_relative '../../spec_helper'

describe Agent::MessageHandler do

  let(:grid) { Grid.create! }
  let(:subject) { described_class.new(grid) }

  describe '#on_container_event' do
    it 'deletes container on destroy event' do
      container = grid.containers.create!(container_id: SecureRandom.hex(16))
      expect {
        subject.on_container_event(grid, {'id' => container.container_id, 'status' => 'destroy'})
      }.to change{ grid.containers.count }.by(-1)
    end
  end
end
require_relative '../spec_helper'

describe GridScheduler do

  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:nodes) do
    nodes = []
    3.times { nodes << HostNode.create!(node_id: SecureRandom.uuid, grid: grid) }
    nodes
  end
  let(:grid_service) { GridService.create!(image_name: 'kontena/redis:2.8', name: 'redis', grid: grid) }
  let(:strategy) { Scheduler::Strategy::HighAvailability.new }
  let(:subject) { described_class.new(grid) }

  describe '#should_reschedule_service?' do
    it 'returns false if service is already in deploy queue' do
      grid_service.grid_service_deploys.create!
      expect(subject.should_reschedule_service?(grid_service)).to be_falsey
    end

    it 'returns false if no available nodes' do
      expect(subject.should_reschedule_service?(grid_service)).to be_falsey
    end

    it 'returns true if service needs deploy' do
      nodes.each { |n| n.set(connected: true) }
      expect(subject.should_reschedule_service?(grid_service)).to be_truthy
    end
  end
end

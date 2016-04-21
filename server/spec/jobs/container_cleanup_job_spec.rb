require_relative '../spec_helper'

describe ContainerCleanupJob do
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  let(:grid) { Grid.create!(name: 'test-grid', overlay_cidr: '10.81.0.0/23') }
  let(:node1) { HostNode.create!(name: "node-1", connected: false, last_seen_at: 2.hours.ago) }
  let(:node2) { HostNode.create!(name: "node-2", connected: true, last_seen_at: 2.seconds.ago) }
  let(:node3) { HostNode.create!(name: "node-3", connected: true, last_seen_at: 3.seconds.ago) }
  let(:subject) { described_class.new(false) }

  describe '#destroy_deleted_containers' do
    it 'destroys containers that have been marked for deletion' do
      Container.create!(
        name: 'foo-1', host_node: node2, grid: grid, deleted_at: 1.minutes.ago
      )
      expect {
        subject.destroy_deleted_containers
      }.to change{ Container.unscoped.count }.by(-1)
    end

    it 'does not destroy containers that have not marked for deletion' do
      Container.create!(
        name: 'foo-1', host_node: node2, grid: grid
      )
      expect {
        subject.destroy_deleted_containers
      }.to change{ Container.unscoped.count }.by(0)
    end
  end

  describe '#cleanup_reserved_overlay_cidrs' do
    let(:allocator) do
      Docker::OverlayCidrAllocator.new(grid)
    end

    it 'removes stale overlay_cidrs' do
      allocator.initialize_grid_subnet
      10.times do |i|
        allocator.allocate_for_service_instance("app-#{i + 1}")
      end

      cidr = allocator.allocate_for_service_instance("app-n")
      cidr.update_attribute(:reserved_at, 21.minutes.ago)
      expect {
        subject.cleanup_reserved_overlay_cidrs
      }.to change{ cidr.reload.reserved_at }.to(nil)
      expect(grid.overlay_cidrs.where(:reserved_at.ne => nil).count).to eq(10)
    end
  end
end

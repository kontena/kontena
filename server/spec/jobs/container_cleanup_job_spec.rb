
describe ContainerCleanupJob, celluloid: true do

  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:node1) { HostNode.create!(name: "node-1", connected: false, last_seen_at: 2.hours.ago, grid: grid) }
  let(:node2) { HostNode.create!(name: "node-2", connected: true, last_seen_at: 2.seconds.ago, grid: grid) }
  let(:node3) { HostNode.create!(name: "node-3", connected: true, last_seen_at: 3.seconds.ago, grid: grid) }
  let(:service) do
    GridService.create!(name: 'test', image_name: 'test:latest', grid: grid)
  end
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
end

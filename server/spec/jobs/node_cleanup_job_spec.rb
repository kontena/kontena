
describe NodeCleanupJob, celluloid: true do

  let(:grid) { Grid.create!(name: 'test') }

  describe '#cleanup_stale_nodes' do
    it 'removes old ephemeral nodes' do
      HostNode.create!(name: "node-1", grid: grid, connected: true, labels: [ 'ephemeral' ], last_seen_at: 12.hours.ago)
      HostNode.create!(name: "node-2", grid: grid, connected: false, labels: [ 'ephemeral' ], last_seen_at: 12.hours.ago)
      HostNode.create!(name: "node-3", grid: grid, connected: true, labels: [ 'ephemeral' ], last_seen_at: 2.hours.ago)

      expect {
        subject.cleanup_stale_nodes
      }.to change{ HostNode.count }.by(-1)
    end

    it 'does not remove initial or non-ephemeral node' do
      HostNode.create!(name: "node-1", grid: grid, connected: false, labels: [], last_seen_at: 2.hours.ago)
      HostNode.create!(name: "node-2", grid: grid, connected: false, labels: [], last_seen_at: 2.hours.ago)
      HostNode.create!(name: "node-3", grid: grid, connected: true, last_seen_at: 10.minutes.ago)

      expect {
        subject.cleanup_stale_nodes
      }.not_to change{ HostNode.count }
    end

    it 'does not remove node with stateful services' do
      HostNode.create!(name: "node-1", grid: grid, connected: false, last_seen_at: 2.hours.ago)
      node2 = HostNode.create!(name: "node-2", grid: grid, connected: false, last_seen_at: 2.hours.ago)
      HostNode.create!(name: "node-3", grid: grid, connected: true, last_seen_at: 10.minutes.ago)
      service = GridService.create!(name: 'test', image_name: 'foo/bar:latest', grid: grid, stateful: true)
      service.containers.create!(name: 'test-1', host_node: node2)
      expect {
        subject.cleanup_stale_nodes
      }.not_to change{ HostNode.count }
    end
  end

  describe '#cleanup_stale_connections' do
    let(:node) do
      HostNode.create!(name: "node-1", grid: grid, connected: false, last_seen_at: 2.hours.ago)
    end

    let(:service) do
      GridService.create!(name: "test", grid: grid, image_name: "my/test:latest")
    end

    it 'does not update node.containers deleted_at if they are already set' do
      container = service.containers.create(
        name: "test-1",
        deleted_at: Time.now,
        host_node: node
      )
      expect {
        subject.cleanup_stale_connections
      }.not_to change{ container.reload.deleted_at }
    end

    it 'does not update node.containers deleted_at if container type is volume' do
      container = service.containers.create(
        name: "test-1",
        container_type: "volume",
        host_node: node
      )
      expect {
        subject.cleanup_stale_connections
      }.not_to change{ container.reload.deleted_at }
    end

    it 'updates node.containers deleted_at if they are not set' do
      container = service.containers.create(name: "test-1", host_node: node)
      expect {
        subject.cleanup_stale_connections
      }.to change{ container.reload.deleted_at }
    end
  end
end

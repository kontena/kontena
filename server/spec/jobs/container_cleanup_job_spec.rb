require_relative '../spec_helper'

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

  describe '#terminate_ghost_containers' do
    it 'terminates containers that does not have a service anymore' do
      container = Container.create!(
        name: 'foo-1', host_node: node2, grid: grid, deleted_at: 1.minutes.ago,
        grid_service_id: GridService.new.id
      )
      expect(subject.wrapped_object).to receive(:terminate_ghost_container).with(container)
      subject.terminate_ghost_containers
    end

    it 'does not terminate container that has a service' do
      container = Container.create!(
        name: 'foo-1', host_node: node2, grid: grid,
        grid_service_id: service.id
      )
      expect(subject.wrapped_object).not_to receive(:terminate_ghost_container)
      subject.terminate_ghost_containers
    end

    it 'removes a container that does not have a host node' do
      container = Container.create!(
        name: 'foo-1', host_node: HostNode.new.id, grid: grid,
        grid_service_id: GridService.new.id
      )
      expect {
        subject.terminate_ghost_containers
      }.to change { Container.unscoped.count }.by(-1)
    end
  end

  describe '#terminate_ghost_container' do
    let(:terminator) do
      double(:terminator)
    end

    it 'forces lb config removal if no replacement service exist' do
      container = Container.create!(
        name: 'foo-1', host_node: node2, grid: grid,
        grid_service_id: GridService.new.id,
        labels: {
          'io;kontena;service;name' => 'invalid',
          'io;kontena;stack;name' => 'invalid'
        }
      )
      allow(subject.wrapped_object).to receive(:service_terminator).and_return(terminator)
      expect(terminator).to receive(:request_terminate_service).with(
        container.grid_service_id, container.instance_number, {lb: true}
      )
      subject.terminate_ghost_container(container)
    end

    it 'does not force lb config removal if replacement service exist' do
      container = Container.create!(
        name: 'foo-1', host_node: node2, grid: grid,
        grid_service_id: GridService.new.id,
        labels: {
          'io;kontena;service;name' => service.name,
          'io;kontena;stack;name' => service.stack.name
        }
      )
      allow(subject.wrapped_object).to receive(:service_terminator).and_return(terminator)
      expect(terminator).to receive(:request_terminate_service).with(
        container.grid_service_id, container.instance_number, {lb: false}
      )
      subject.terminate_ghost_container(container)
    end
  end
end

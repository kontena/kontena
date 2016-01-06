require_relative '../spec_helper'

describe GridServiceInstanceDeployer do
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:grid_service) { GridService.create!(image_name: 'kontena/redis:2.8', name: 'redis', grid: grid) }
  let(:node) { HostNode.create!(node_id: SecureRandom.uuid) }
  let(:strategy) { Scheduler::Strategy::HighAvailability.new }
  let(:subject) { described_class.new(grid_service) }

  describe '#service_exists_on_node?' do
    it 'returns true if service exists on node' do
      grid_service.containers.create!(name: 'redis-2', host_node: node)
      expect(subject.service_exists_on_node?(node, 2)).to be_truthy
    end

    it 'returns false if service does not exists on node' do
      grid_service.containers.create!(name: 'redis-2', host_node: node)
      expect(subject.service_exists_on_node?(node, 1)).to be_falsey
    end
  end

  describe '#deployed_service_container_exists?' do
    it 'returns true if service exists' do
      grid_service.containers.create!(name: 'redis-2', host_node: node, deploy_rev: 'rev-a', container_id: 'aaa')
      expect(subject.deployed_service_container_exists?(2, 'rev-a')).to be_truthy
    end

    it 'returns false if service does not have container_id' do
      grid_service.containers.create!(name: 'redis-2', host_node: node, deploy_rev: 'rev-a')
      expect(subject.deployed_service_container_exists?(2, 'rev-a')).to be_falsey
    end

    it 'returns false if service does not have same rev' do
      grid_service.containers.create!(name: 'redis-2', host_node: node, deploy_rev: 'rev-b')
      expect(subject.deployed_service_container_exists?(2, 'rev-a')).to be_falsey
    end

    it 'returns false if service instance does not exist' do
      grid_service.containers.create!(name: 'redis-1', host_node: node, deploy_rev: 'rev-a', container_id: 'aaa')
      expect(subject.deployed_service_container_exists?(2, 'rev-a')).to be_falsey
    end
  end
end
require_relative '../../../spec_helper'

describe Scheduler::Filter::Dependency do

  let(:nodes) do
    nodes = []
    nodes << HostNode.create!(node_id: 'node1', name: 'node-1', labels: ['az-1', 'ssd'])
    nodes << HostNode.create!(node_id: 'node2', name: 'node-2', labels: ['az-1', 'hdd'])
    nodes << HostNode.create!(node_id: 'node3', name: 'node-3', labels: ['az-2', 'ssd'])
    nodes
  end
  let(:mysql_service) {
    GridService.create(name: 'mysql', image_name: 'mysql:latest')
  }
  let(:logstash_service) {
    GridService.create(name: 'mysql', image_name: 'mysql:latest')
  }

  describe '#filter_candidates_by_volume' do
    it 'finds no candidates if no volumes match' do
      logstash_service.volumes_from = ['mysql-service-%s']
      subject.filter_candidates_by_volume(nodes, logstash_service, 2)
      expect(nodes).to eq([])
    end
  end

  describe '#filter_by_volume?' do
    it 'returns true if service has volumes_from' do
      logstash_service.volumes_from = ['mysql-service-%s']
      expect(subject.filter_by_volume?(logstash_service)).to eq(true)
    end

    it 'returns false if service has no volumes_from' do
      expect(subject.filter_by_volume?(logstash_service)).to eq(false)
    end
  end

  describe '#filter_by_net?' do
    it 'returns true if service network points to container' do
      logstash_service.net = 'container:mysql_service-%s'
      expect(subject.filter_by_net?(logstash_service)).to eq(true)
    end

    it 'returns false if service net is host' do
      logstash_service.net = 'host'
      expect(subject.filter_by_net?(logstash_service)).to eq(false)
    end

    it 'returns false if service has no network setting' do
      expect(subject.filter_by_net?(logstash_service)).to eq(false)
    end
  end
end

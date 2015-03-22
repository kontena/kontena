require_relative '../spec_helper'

describe GridServiceDeployer do

  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:grid_service) { GridService.create!(image_name: 'kontena/redis:2.8', name: 'redis', grid: grid) }
  let(:node) { HostNode.create!(node_id: SecureRandom.uuid) }
  let(:strategy) { Scheduler::Strategy::HighAvailability.new }
  let(:subject) { described_class.new(strategy, grid_service, []).wrapped_object }
  let(:ubuntu_trusty) { Image.create!(name:'ubuntu-trusty', exposed_ports: [{'port' => '3306', 'protocol' => 'tcp'}]) }

  describe '#deploy_service_container' do
    it 'calls create and start' do
      container = spy
      allow(subject).to receive(:container_running?).and_return(true)
      expect(subject).to receive(:create_service_container).with(node, 'redis-1', 'v1.0').and_return(container)
      expect(subject).to receive(:start_service_container).with(container)
      subject.deploy_service_container(node, 'redis-1', 'v1.0')
    end

    it 'removes previous container if it exists' do
      container = grid_service.containers.create!(name: 'redis-1', container_id: 'foo')
      allow(container).to receive(:exists_on_node?).and_return(true)
      allow(grid_service).to receive(:container_by_name).and_return(container)
      allow(subject).to receive(:container_running?).and_return(true)
      allow(subject).to receive(:create_service_container).and_return(spy)
      allow(subject).to receive(:start_service_container).once
      expect(subject).to receive(:remove_service_container).with(container).once

      subject.deploy_service_container(node, 'redis-1', 'v1.0')
    end
  end

  describe '#ensure_image' do
    it 'calls ImagePuller for image update' do
      image = 'redis:2.8'
      puller = spy
      allow(subject).to receive(:image_puller).and_return(puller)
      expect(subject).to receive(:image_puller).with(node, nil)
      expect(puller).to receive(:pull_image).with(image).and_return(ubuntu_trusty)
      subject.ensure_image(node, image)
    end
  end
end

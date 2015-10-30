require_relative '../spec_helper'

describe GridServiceDeployer do
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:grid_service) { GridService.create!(image_name: 'kontena/redis:2.8', name: 'redis', grid: grid) }
  let(:node) { HostNode.create!(node_id: SecureRandom.uuid) }
  let(:strategy) { Scheduler::Strategy::HighAvailability.new }
  let(:subject) { described_class.new(strategy, grid_service, []) }
  let(:ubuntu_trusty) { Image.create!(name:'ubuntu-trusty', image_id: '86ce37374f40e95cfe8af7327c34ea9919ef216ea965377565fcfad3c378a2c3', exposed_ports: [{'port' => '3306', 'protocol' => 'tcp'}]) }

  describe '#deploy_service_instance' do
    it 'calls create_service_instance' do
      container = spy
      expect(subject).to receive(:create_service_instance).with(node, 1, 'v1.0')
      expect(subject).to receive(:wait_for_service_to_start).and_return(true)
      subject.deploy_service_instance(node, 1, 'v1.0')
    end

    it 'calls terminate_service_instance if it exists on different node' do
      grid_service.image = ubuntu_trusty
      grid_service.save
      container = grid_service.containers.create!(
        name: 'redis-1',
        container_id: 'foo',
        host_node: HostNode.create!(name: 'another', node_id: SecureRandom.uuid)
      )

      allow(subject).to receive(:wait_for_service_to_start).and_return(true)
      expect(subject).to receive(:create_service_instance).with(node, 1, 'v1.0')
      expect(subject).to receive(:terminate_service_instance).with(1).once

      subject.deploy_service_instance(node, 1, 'v1.0')
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

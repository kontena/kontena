require_relative '../../spec_helper'

describe Docker::ContainerCreator do

  let(:client) { spy(:client) }
  let(:grid_service) { GridService.create!(name: 'test', image_name: 'redis:2.8') }
  let(:ubunty_trusty) { Image.create!(name:'ubuntu-trusty', exposed_ports: [{'port' => '3306', 'protocol' => 'tcp'}]) }
  let(:host_node) { HostNode.create!(node_id: SecureRandom.uuid) }
  let(:container) { Container.create!(name: 'redis-1', grid_service: grid_service, host_node: host_node, image: 'redis:2.8') }
  let(:subject) { described_class.new(grid_service, host_node) }

  describe '#create_container' do
    it 'calls #request_create_container' do
      allow(host_node).to receive(:rpc_client).and_return(client)
      expect(subject).to receive(:request_create_container).and_return({})
      allow(subject).to receive(:sync_container_with_docker_response)
      subject.create_container('foo-1', 'rev1')
    end

    it 'creates a new container' do
      docker_response = {'State' => {}, 'Config' => {}, 'NetworkSettings' => {}, 'Volumes' => {}}
      expect(subject).to receive(:request_create_container).and_return(docker_response)
      expect {
        subject.create_container('foo-1', 'rev1')
      }.to change{ grid_service.containers.count }.by(1)
    end

    it 'creates a data volume container if service is stateful' do
      grid_service.stateful = true
      container_response = {'Id' => 'aa', 'State' => {}, 'Config' => {}, 'NetworkSettings' => {}, 'Volumes' => {}}
      expect(subject).to receive(:request_create_container).with(
        hash_including('name' => 'foo-1')
      ).once.and_return(container_response)

      volume_response = {'Id' => 'bb', 'State' => {}, 'Config' => {}, 'NetworkSettings' => {}, 'Volumes' => {}}
      expect(subject).to receive(:request_create_container).with(
          hash_including('name' => 'foo-1-volumes')
      ).once.and_return(volume_response)

      expect {
        subject.create_container('foo-1', 'rev1')
      }.to change{ grid_service.containers.volumes.count }.by(1)
    end
  end

  describe '#ensure_volume_container' do

    let(:docker_opts) { {'Image' => container.image} }

    it 'sends container create call to docker' do
      volume_response = {'Id' => 'bb', 'State' => {}, 'Config' => {}, 'NetworkSettings' => {}, 'Volumes' => {}}
      expect(subject).to receive(:request_create_container).with(
        hash_including('name' => "#{container.name}-volumes")
      ).once.and_return(volume_response)
      subject.ensure_volume_container(container, docker_opts)
    end

    it 'sets dummy value to overlay_cidr' do
      volume_response = {'Id' => 'bb', 'State' => {}, 'Config' => {}, 'NetworkSettings' => {}, 'Volumes' => {}}
      allow(subject).to receive(:request_create_container).with(
        hash_including('name' => "#{container.name}-volumes")
      ).once.and_return(volume_response)
      volume_container = subject.ensure_volume_container(container, docker_opts)
      expect(volume_container.overlay_cidr).not_to be_nil
    end
  end
end

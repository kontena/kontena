require_relative '../../spec_helper'

describe Docker::ContainerCreator do

  let(:client) do
    spy(:client)
  end

  let(:grid_service) do
    GridService.create!(name: 'test', image_name: 'redis:2.8')
  end

  let(:ubunty_trusty) do
    Image.create!(name:'ubuntu-trusty', exposed_ports: [{'port' => '3306', 'protocol' => 'tcp'}])
  end

  let(:host_node) do
    HostNode.create!(node_id: SecureRandom.uuid)
  end

  let(:subject) do
    described_class.new(grid_service, host_node)
  end

  describe '#create_container' do
    it 'calls #request_create_container' do
      allow(host_node).to receive(:rpc_client).and_return(client)
      expect(subject).to receive(:request_create_container).and_return({})
      allow(subject).to receive(:sync_container_with_docker_response)
      subject.create_container('foo-1', 'rev1')
    end

    it 'creates a new container' do
      docker_opts = {foo: 'bar'}
      docker_response = {'State' => {}, 'Config' => {}, 'NetworkSettings' => {}, 'Volumes' => {}}
      image = Image.create(name: 'redis:2.8')
      expect(subject).to receive(:request_create_container).and_return(docker_response)
      expect {
        subject.create_container('foo-1', 'rev1')
      }.to change{ grid_service.containers.count }.by(1)
    end
  end
end

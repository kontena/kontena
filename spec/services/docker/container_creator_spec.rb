require_relative '../../spec_helper'

describe Docker::ContainerCreator do

  let(:client) do
    spy(:client)
  end

  let(:grid_service) do
    GridService.create!(name: 'test', image_name: 'redis:2.8', grid_service_links: [GridServiceLink.new(alias: 'test', linked_grid_service: linked_grid_service)])
  end

  let(:linked_grid_service) do
    grid_service = GridService.create!(name: 'linked-service-test', image_name: 'ubuntu-trusty', image: ubunty_trusty)
    Container.create(grid_service: grid_service, name: 'linked-service-test-1', network_settings: {'ip_address' => '0.0.0.0'}, image: 'ubuntu_trusty', env: ['SOME_KEY=value'])
    grid_service
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
      expect(subject).to receive(:request_create_container)
      subject.create_container('foo-1', 'rev1')
    end
  end

  describe '#build_linked_services_env_vars' do
    context 'when linked service has one container' do
      it 'generates env variables from exposed ports of image without container index' do
        env_vars = subject.build_linked_services_env_vars
        expect(env_vars).to include('TEST_PORT_3306_TCP=tcp://0.0.0.0:3306')
        expect(env_vars).to include('TEST_PORT_3306_TCP_PORT=3306')
        expect(env_vars).to include('TEST_PORT_3306_TCP_ADDR=0.0.0.0')
        expect(env_vars).to include('TEST_PORT_3306_TCP_PROTO=tcp')
      end

      it 'generates env variables from linked grid service containers' do
        expect(subject.build_linked_services_env_vars).to include('TEST_ENV_SOME_KEY=value')
      end
    end

    context 'when linked service has multiple containers' do
      before :each do
        Container.create(grid_service: linked_grid_service, name: 'linked-service-test-2', network_settings: {'ip_address' => '0.0.0.1'}, image: 'ubuntu_trusty', env: ['SOME_KEY=value'])
      end
      it 'generates env variables from exposed ports of image with container index' do
        env_vars = subject.build_linked_services_env_vars
        expect(env_vars).to include('TEST_1_PORT_3306_TCP=tcp://0.0.0.0:3306')
        expect(env_vars).to include('TEST_1_PORT_3306_TCP_PORT=3306')
        expect(env_vars).to include('TEST_1_PORT_3306_TCP_ADDR=0.0.0.0')
        expect(env_vars).to include('TEST_1_PORT_3306_TCP_PROTO=tcp')
        expect(env_vars).to include('TEST_2_PORT_3306_TCP=tcp://0.0.0.1:3306')
        expect(env_vars).to include('TEST_2_PORT_3306_TCP_PORT=3306')
        expect(env_vars).to include('TEST_2_PORT_3306_TCP_ADDR=0.0.0.1')
        expect(env_vars).to include('TEST_2_PORT_3306_TCP_PROTO=tcp')
      end

      it 'generates env variables from linked grid service containers' do
        expect(subject.build_linked_services_env_vars).to include('TEST_1_ENV_SOME_KEY=value')
        expect(subject.build_linked_services_env_vars).to include('TEST_2_ENV_SOME_KEY=value')
      end
    end
  end

  describe '#request_create_container' do
    it 'creates a new container' do
      docker_opts = {foo: 'bar'}
      docker_response = {'State' => {}, 'Config' => {}, 'NetworkSettings' => {}, 'Volumes' => {}}
      image = Image.create(name: 'redis:2.8')
      expect(client).to receive(:request).with('/containers/create', docker_opts).and_return(docker_response)
      expect {
        subject.request_create_container(client, image, docker_opts, 'rev2')
      }.to change{ grid_service.containers.count }.by(1)
    end
  end
end

describe Rpc::ContainerInfoMapper do
  let(:grid) { Grid.create! }
  let(:node) { grid.create_node!('node-1', node_id: 'aaa') }
  let(:node2) { grid.create_node!('node-2', node_id: 'bbb') }
  let(:service) do
    GridService.create!(
      grid: grid,
      name: 'app',
      image_name: 'my/app:latest'
    )
  end
  let(:subject) { described_class.new(grid) }

  describe '#update_service_container' do
    let(:container) do
      service.containers.create!(name: 'app-1', host_node: node, container_id: SecureRandom.hex(32))
    end

    let(:data) do
      {
        'Id' => container.container_id,
        'Config' => {
            'Labels' => {}
        }
      }
    end

    it 'updates container host_node' do
      node2
      subject.update_service_container('bbb', container, data)
      expect(container.reload.host_node).to eq(node2)
    end

    it 'does not leak references' do
      node2
      subject.update_service_container('bbb', container, data)
      expect(grid.containers.in_memory.size).to eq(0)
    end
  end

  describe '#create_service_container' do
    let(:data) do
      {
        'Id' => SecureRandom.hex(32),
        'Config' => {
          'Labels' => {
            'io.kontena.service.id' => service.id.to_s,
            'io.kontena.container.id' => Container.new.id.to_s,
          }
        }
      }
    end

    it 'creates a new container to grid' do
      expect {
        subject.create_service_container(node.node_id, data)
      }.to change{ service.containers.count }.by(1)
    end

    it 'does not leak in memory references' do
      subject.create_service_container(node.node_id, data)
      expect(grid.containers.in_memory.size).to eq(0)
    end
  end

  describe '#container_attributes_from_docker' do
    let(:container) {
      Container.create!(
        grid: grid,
        grid_service: service,
        host_node: node
      )
    }
    let(:docker_data) do
      {
        'Config' => {
          'Labels' => {}
        },
        'State' => {

        }
      }
    end

    it 'sets container_id' do
      docker_data['Id'] = 'random_id'
      subject.container_attributes_from_docker(container, docker_data)
      expect(container.container_id).to eq('random_id')
    end

    it 'sets deploy_rev' do
      docker_data['Config']['Labels']['io.kontena.container.deploy_rev'] = 'rev1.1'
      subject.container_attributes_from_docker(container, docker_data)
      expect(container.deploy_rev).to eq('rev1.1')
    end

    it 'sets image' do
      docker_data['Config']['Image'] = 'my/app:latest'
      subject.container_attributes_from_docker(container, docker_data)
      expect(container.image).to eq('my/app:latest')
    end

    it 'sets image_version' do
      docker_data['Image'] = 'image_id'
      subject.container_attributes_from_docker(container, docker_data)
      expect(container.image_version).to eq('image_id')
    end

    it 'sets image_version' do
      docker_data['Config']['Cmd'] = ['npm', 'start']
      subject.container_attributes_from_docker(container, docker_data)
      expect(container.cmd).to eq(['npm', 'start'])
    end

    it 'sets env' do
      docker_data['Config']['Env'] = ['FOO=bar']
      subject.container_attributes_from_docker(container, docker_data)
      expect(container.env).to eq(['FOO=bar'])
    end

    it 'strips secrets from env' do
      service.secrets.create(secret: 'TEST_FOO', name: 'FOO', type: 'env')
      docker_data['Config']['Env'] = ['FOO=bar','BAR=baz']
      subject.container_attributes_from_docker(container, docker_data)
      expect(container.env).to eq(['BAR=baz'])
    end

    it 'sets labels' do
      docker_data['Config']['Labels'] = {
        'io.kontena.service.name' => 'test',
        'io.kontena.grid.name' => 'first-grid',
      }
      subject.container_attributes_from_docker(container, docker_data)
      expect(container.labels['io;kontena;service;name']).to eq('test')
      expect(container.labels['io;kontena;grid;name']).to eq('first-grid')
    end

    it 'sets hostname' do
      docker_data['Config']['Hostname'] = 'test-1'
      subject.container_attributes_from_docker(container, docker_data)
      expect(container.hostname).to eq('test-1')
    end

    it 'sets domainname' do
      docker_data['Config']['Domainname'] = 'mygrid.kontena.local'
      subject.container_attributes_from_docker(container, docker_data)
      expect(container.domainname).to eq('mygrid.kontena.local')
    end

    it 'sets running state' do
      docker_data['State']['Running'] = true
      subject.container_attributes_from_docker(container, docker_data)
      expect(container.state[:running]).to eq(true)
    end

  end

  describe '#parse_docker_network_settings' do
    let(:docker_data) do
      {
        "Bridge" => "docker0",
        "Gateway" => "172.17.42.1",
        "IPAddress" => "172.17.0.26",
        "IPPrefixLen" => 16,
        "MacAddress" => "02:42:ac:11:00:1a",
        "PortMapping" => nil,
        "Ports" => {
          "6379/tcp" => [
            {
              "HostIp" => "0.0.0.0",
              "HostPort" => "6379"
            }
          ]
        }
      }
    end

    it 'parses ports correctly' do
      res = subject.parse_docker_network_settings(docker_data)
      expect(res[:ports]).to eq(
        "6379/tcp" => [
          {
            node_ip: "0.0.0.0",
            node_port: 6379
          }
        ]
      )
    end
  end

  describe 'parse_labels' do
    let(:labels) {
      {
        'io.kontena.service.name' => 'foobar',
        'io.kontena.grid.name' => 'test'
      }
    }

    it 'parses labels correctly' do
      parsed_labels = subject.parse_labels(labels)
      expect(parsed_labels['io;kontena;service;name']).to eq('foobar')
    end
  end
end

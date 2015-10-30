require_relative '../../spec_helper'

describe Agent::ContainerInfoMapper do
  let(:grid) { Grid.create! }
  let(:node) { HostNode.create!(name: 'node-1', node_id: 'aaa', grid: grid) }
  let(:service) do
    GridService.create!(
      grid: grid,
      name: 'app',
      image_name: 'my/app:latest'
    )
  end
  let(:subject) { described_class.new(grid) }

  describe '#from_agent' do


  end

  describe '#create_service_container' do
    it 'creates a new container to grid' do
      data= {
        'Id' => SecureRandom.hex(32),
        'Config' => {
          'Labels' => {
            'io.kontena.service.id' => service.id.to_s,
            'io.kontena.container.id' => Container.new.id.to_s,
          }
        }
      }
      expect {
        subject.create_service_container(node.node_id, data)
      }.to change{ service.containers.count }.by(1)
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

    it 'sets env' do
      docker_data['Config']['Env'] = ['FOO=bar']
      subject.container_attributes_from_docker(container, docker_data)
      expect(container.env).to eq(['FOO=bar'])
    end

    it 'sets running state' do
      docker_data['State']['Running'] = true
      subject.container_attributes_from_docker(container, docker_data)
      expect(container.state[:running]).to eq(true)
    end

    it 'sets overlay_cidr' do
      overlay_cidr = grid.overlay_cidrs.create(ip: '10.81.23.2', subnet: '19')
      docker_data['Config']['Labels']['io.kontena.container.overlay_cidr'] = overlay_cidr.to_s
      subject.container_attributes_from_docker(container, docker_data)
      expect(container.reload.overlay_cidr).to eq(overlay_cidr)
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
end

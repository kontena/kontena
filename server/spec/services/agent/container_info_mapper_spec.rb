require_relative '../../spec_helper'

describe Agent::ContainerInfoMapper do
  let(:grid) { Grid.create! }
  let(:node) { HostNode.create!(name: 'node-1', node_id: 'aaa', grid: grid) }
  let(:node2) { HostNode.create!(name: 'node-2', node_id: 'bbb', grid: grid) }
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

    it 'updates container host_node' do
      data = {
          'Id' => container.container_id,
          'Config' => {
              'Labels' => {}
          }
      }
      node2
      subject.update_service_container('bbb', container, data)
      expect(container.reload.host_node).to eq(node2)
    end
  end

  describe '#create_service_container' do
    it 'creates a new container to grid' do
      data = {
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

    it 'strips secrets from env' do
      service.secrets.create(secret: 'TEST_FOO', name: 'FOO', type: 'env')
      docker_data['Config']['Env'] = ['FOO=bar','BAR=baz']
      subject.container_attributes_from_docker(container, docker_data)
      expect(container.env).to eq(['BAR=baz'])
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

  describe '#parse_networks' do
    let(:docker_data) do
      {
        "kontena" => {
            "IPAMConfig" => nil,
            "Links" => nil,
            "Aliases" => [
                "e8c0e459f3b5"
            ],
            "NetworkID" => "157e6b330cd70dda02259b166dadba76dfdf9a0ef3da687bfdc5a24c15ae2bd0",
            "EndpointID" => "6b92a960eb0560545bce26a366fd36ae02e393c588e6cb64299c5a0904a2eb1c",
            "Gateway" => "",
            "IPAddress" => "10.81.128.76",
            "IPPrefixLen" => 16,
            "IPv6Gateway" => "",
            "GlobalIPv6Address" => "",
            "GlobalIPv6PrefixLen" => 0,
            "MacAddress" => "72:03:d0:8c:6f:fc"
        }
      }
    end

    it 'parses networks correctly' do
      res = subject.parse_networks(docker_data)
      expect(res).to eq({
          "kontena" => {
              ip_address: "10.81.128.76",
              ip_prefix_len: 16,
              mac_address: "72:03:d0:8c:6f:fc"
          }
        })
    end

  end
end

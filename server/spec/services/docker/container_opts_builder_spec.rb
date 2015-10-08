require_relative '../../spec_helper'

describe Docker::ContainerOptsBuilder do

  let(:grid) { Grid.create!(name: 'test') }
  let(:grid_service) do
    GridService.create!(
      name: 'test',
      grid: grid,
      image_name: 'redis:2.8',
      grid_service_links: [
        GridServiceLink.new(alias: 'test', linked_grid_service: linked_grid_service)
      ]
    )
  end

  let(:linked_grid_service) do
    grid_service = GridService.create!(
      name: 'linked-service-test',
      image_name: 'ubuntu-trusty',
      image: ubunty_trusty
    )
    Container.create(
      grid_service: grid_service,
      name: 'linked-service-test-1',
      network_settings: {'ip_address' => '0.0.0.0'},
      image: 'ubuntu_trusty',
      env: ['SOME_KEY=value']
    )
    grid_service
  end

  let(:ubunty_trusty) do
    Image.create!(name:'ubuntu-trusty', exposed_ports: [{'port' => '3306', 'protocol' => 'tcp'}])
  end

  describe '.build_opts' do
    let(:container) { grid_service.containers.build(name: 'redis-1')}

    it 'sets name' do
      opts = described_class.build_opts(grid_service, container)
      expect(opts['name']).to eq('redis-1')
    end

    it 'sets Image' do
      opts = described_class.build_opts(grid_service, container)
      expect(opts['Image']).to eq(grid_service.image_name)
    end

    it 'sets Hostname' do
      opts = described_class.build_opts(grid_service, container)
      expect(opts['Hostname']).to eq('redis-1.kontena.local')
    end

    it 'sets ExposedPorts & PortBindings' do
      grid_service.ports = [
        {
          'ip' => '0.0.0.0',
          'container_port' => 80,
          'node_port' => 80,
          'protocol' => 'tcp'
        }
      ]
      opts = described_class.build_opts(grid_service, container)
      expect(opts['ExposedPorts']).to include('80/tcp' => {})
      expect(opts['HostConfig']['PortBindings']['80/tcp']).to include(
        {'HostPort' => '80'}
      )
    end

    it 'does not set ExposedPorts & PortBindings when network mode is not bridge' do
      grid_service.net = 'host'
      grid_service.ports = [
        {
          'ip' => '0.0.0.0',
          'container_port' => 80,
          'node_port' => 80,
          'protocol' => 'tcp'
        }
      ]
      opts = described_class.build_opts(grid_service, container)
      expect(opts['ExposedPorts']).to eq(nil)
      expect(opts['HostConfig']['PortBindings']).to eq(nil)
    end

    it 'sets Memory' do
      grid_service.memory = 128.megabytes
      opts = described_class.build_opts(grid_service, container)
      expect(opts['HostConfig']['Memory']).to eq(128.megabytes)
    end

    it 'sets MemorySwap' do
      grid_service.memory_swap = 192.megabytes
      opts = described_class.build_opts(grid_service, container)
      expect(opts['HostConfig']['MemorySwap']).to eq(192.megabytes)
    end

    it 'sets CpuShares' do
      grid_service.cpu_shares = 500
      opts = described_class.build_opts(grid_service, container)
      expect(opts['HostConfig']['CpuShares']).to eq(500)
    end

    it 'sets CapAdd' do
      grid_service.cap_add = ['NET_ADMIN']
      opts = described_class.build_opts(grid_service, container)
      expect(opts['HostConfig']['CapAdd']).to eq(['NET_ADMIN'])
    end

    it 'does not set CapAdd if it\'s not set' do
      opts = described_class.build_opts(grid_service, container)
      expect(opts['HostConfig']['CapAdd']).to be_nil
    end

    it 'sets CapDrop' do
      grid_service.cap_drop = ['SETUID']
      opts = described_class.build_opts(grid_service, container)
      expect(opts['HostConfig']['CapDrop']).to eq(['SETUID'])
    end

    it 'does not set CapDrop if it\'s not set' do
      opts = described_class.build_opts(grid_service, container)
      expect(opts['HostConfig']['CapDrop']).to be_nil
    end

    it 'sets Privileged' do
      grid_service.privileged = true
      opts = described_class.build_opts(grid_service, container)
      expect(opts['HostConfig']['Privileged']).to eq(true)
    end

    it 'does not set Privileged if privileged is nil' do
      grid_service.privileged = nil
      opts = described_class.build_opts(grid_service, container)
      expect(opts['HostConfig'].has_key?('Privileged')).to eq(false)
    end

    it 'sets NetworkMode' do
      grid_service.net = 'host'
      opts = described_class.build_opts(grid_service, container)
      expect(opts['HostConfig']['NetworkMode']).to eq('host')
    end

    it 'does not set NetworkMode if net is nil' do
      grid_service.net = nil
      opts = described_class.build_opts(grid_service, container)
      expect(opts['HostConfig'].has_key?('NetworkMode')).to eq(false)
    end

    it 'sets logging driver' do
      grid_service.log_driver = 'gelf'
      opts = described_class.build_opts(grid_service, container)
      expect(opts['HostConfig']['LogConfig']['Type']).to eq('gelf')
    end

    it 'sets logging opts' do
      grid_service.log_driver = 'gelf'
      grid_service.log_opts = {:'gelf-address'=>'udp://192.168.0.42:12201', :'gelf-tag'=>'foo'}
      opts = described_class.build_opts(grid_service, container)
      expect(opts['HostConfig']['LogConfig']['Type']).to eq('gelf')
      expect(opts['HostConfig']['LogConfig']['Config'].size).to eq(2)
      expect(opts['HostConfig']['LogConfig']['Config']['gelf-address']).to eq('udp://192.168.0.42:12201')
      expect(opts['HostConfig']['LogConfig']['Config']['gelf-tag']).to eq('foo')

    end

  end

  describe '.build_labels' do
    let(:container) { grid_service.containers.build(name: 'redis-1')}

    it 'sets base labels' do
      labels = described_class.build_labels(grid_service, container)
      expect(labels).to include('io.kontena.container.name' => container.name)
      expect(labels).to include('io.kontena.service.id' => grid_service.id.to_s)
      expect(labels).to include('io.kontena.service.name' => grid_service.name)
      expect(labels).to include('io.kontena.grid.name' => grid_service.grid.name)
    end

    it 'does not set load balancer labels if service is not linked to any' do
      labels = described_class.build_labels(grid_service, container)
      expect(labels.keys).not_to include('io.kontena.load_balancer.name')
    end

    it 'sets load balancer labels if service is linked to load balancer' do
      lb = GridService.create!(
        name: 'lb', image_name: 'kontena/lb:latest', grid: grid
      )
      grid_service.grid_service_links << GridServiceLink.new(linked_grid_service: lb)
      grid_service.save
      labels = described_class.build_labels(grid_service, container)
      expect(labels).to include('io.kontena.load_balancer.name' => lb.name)
      expect(labels).to include('io.kontena.load_balancer.mode' => 'http')
      expect(labels).to include('io.kontena.load_balancer.internal_port' => '80')
    end

  end

  describe '.build_volumes' do
    it 'returns correct volumes hash' do
      grid_service.volumes = ['/foo/bar', '/var/run/docker.sock:/var/run/docker.sock:ro']
      expect(described_class.build_volumes(grid_service)).to eq({'/foo/bar' => {}, '/var/run/docker.sock' => {}})
    end
  end

  describe '#build_bind_volumes' do
    it 'returns correct volume bind array' do
      grid_service.volumes = ['/foo/bar', '/var/run/docker.sock:/var/run/docker.sock']
      expect(described_class.build_bind_volumes(grid_service)).to eq(['/var/run/docker.sock:/var/run/docker.sock'])
    end
  end

  describe '.build_linked_services_env_vars' do
    context 'when linked service has one container' do
      it 'generates env variables from exposed ports of image without container index' do
        env_vars = described_class.build_linked_services_env_vars(grid_service)
        expect(env_vars).to include('TEST_PORT_3306_TCP=tcp://0.0.0.0:3306')
        expect(env_vars).to include('TEST_PORT_3306_TCP_PORT=3306')
        expect(env_vars).to include('TEST_PORT_3306_TCP_ADDR=0.0.0.0')
        expect(env_vars).to include('TEST_PORT_3306_TCP_PROTO=tcp')
      end

      it 'generates env variables from linked grid service containers' do
        expect(described_class.build_linked_services_env_vars(grid_service)).to include('TEST_ENV_SOME_KEY=value')
      end
    end

    context 'when linked service has multiple containers' do
      before :each do
        Container.create(grid_service: linked_grid_service, name: 'linked-service-test-2', network_settings: {'ip_address' => '0.0.0.1'}, image: 'ubuntu_trusty', env: ['SOME_KEY=value'])
      end
      it 'generates env variables from exposed ports of image with container index' do
        env_vars = described_class.build_linked_services_env_vars(grid_service)
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
        expect(described_class.build_linked_services_env_vars(grid_service)).to include('TEST_1_ENV_SOME_KEY=value')
        expect(described_class.build_linked_services_env_vars(grid_service)).to include('TEST_2_ENV_SOME_KEY=value')
      end
    end
  end
end

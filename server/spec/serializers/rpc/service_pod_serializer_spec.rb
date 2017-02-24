require_relative '../../spec_helper'

describe Rpc::ServicePodSerializer do
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:node) { HostNode.create!(name: 'node-1', node_id: 'a') }
  let(:lb) do
    GridService.create!(
      name: 'lb',
      grid: grid,
      image_name: 'kontena/lb:latest'
    )
  end
  let(:service) do
    GridService.create!(
      name: 'app',
      grid: grid,
      image_name: 'my/app:latest',
      container_count: 2,
      env: ['FOO=bar'],
      networks: [grid.networks.first],
      volumes: ['volA:/data', 'ext-vol:/foo']
    )
  end
  let(:service_instance) do
    service.grid_service_instances.create!(
      instance_number: 2,
      desired_state: 'running',
      deploy_rev: 12,
      host_node: node
    )
  end
  let(:subject) { described_class.new(service_instance) }

  let! :volume do
    service.stack.volumes.create(grid: service.grid, name: 'volA', scope: 'node')
  end

  let! :ext_vol do
    vol = Volume.create(grid: grid, name: 'ext-vol', scope: 'node')
    service.stack.external_volumes.create!(name: 'ext-vol', volume: vol)
    vol
  end

  describe '#to_hash' do

    it 'includes service_name' do
      expect(subject.to_hash).to include(:service_name => 'app')
    end

    it 'includes instance_number' do
      expect(subject.to_hash).to include(:instance_number => 2)
    end

    it 'includes image_name' do
      expect(subject.to_hash).to include(:image_name => service.image_name)
    end

    it 'includes deploy_rev' do
      expect(subject.to_hash).to include(:deploy_rev => '12')
    end

    it 'includes stateful' do
      expect(subject.to_hash).to include(:stateful => false)
    end

    it 'includes user' do
      expect(subject.to_hash).to include(:user => nil)
    end

    it 'includes cmd' do
      expect(subject.to_hash).to include(:cmd => nil)
    end

    it 'includes memory' do
      expect(subject.to_hash).to include(:memory => nil)
    end

    it 'includes memory_swap' do
      expect(subject.to_hash).to include(:memory_swap => nil)
    end

    it 'includes cpu_shares' do
      expect(subject.to_hash).to include(:cpu_shares => nil)
    end

    it 'includes privileged' do
      expect(subject.to_hash).to include(:privileged => nil)
    end

    it 'includes cap_add' do
      expect(subject.to_hash).to include(:cap_add => [])
    end

    it 'includes cap_drop' do
      expect(subject.to_hash).to include(:cap_drop => [])
    end

    it 'includes devices' do
      expect(subject.to_hash).to include(:devices => [])
    end

    it 'includes ports' do
      expect(subject.to_hash).to include(:ports => [])
    end

    it 'includes volumes' do
      expect(subject.to_hash).to include(:volumes => ['volA:/data', 'ext-vol:/foo'])
    end

    it 'includes volumes_from' do
      expect(subject.to_hash).to include(:volumes_from => [])
    end

    it 'includes net' do
      expect(subject.to_hash).to include(:net => 'bridge')
    end

    it 'includes log_driver' do
      expect(subject.to_hash).to include(:log_driver => nil)
    end

    it 'includes log_opts' do
      expect(subject.to_hash).to include(:log_opts => {})
    end

    it 'includes hooks' do
      expect(subject.to_hash).to include(:hooks => [])
    end

    it 'includes secrets' do
      expect(subject.to_hash).to include(:secrets => [])
    end

    it 'includes default network' do
      expect(subject.to_hash).to include(:networks => [{name: 'kontena', subnet: '10.81.0.0/16', multicast: true, internal: false}])
    end

    it 'includes volume specs' do
      expect(service_spec).to include(:volume_specs => [
        {name: 'volA', scope: 'node', driver: 'local', driver_opts: {}},
        {name: 'ext-vol', scope: 'node', driver: 'local', driver_opts: {}}
      ])
    end

    describe '[:env]' do
      let(:env) { subject.to_hash[:env] }

      it 'includes saved env variable' do
        expect(env).to include('FOO=bar')
      end

      it 'includes default service variables' do
        expect(env).to include("KONTENA_SERVICE_ID=#{service.id.to_s}")
        expect(env).to include("KONTENA_SERVICE_NAME=#{service.name.to_s}")
        expect(env).to include("KONTENA_GRID_NAME=#{service.grid.name.to_s}")
        expect(env).to include("KONTENA_STACK_NAME=#{service.stack.name.to_s}")
        expect(env).to include("KONTENA_NODE_NAME=#{node.name.to_s}")
        expect(env).to include("KONTENA_SERVICE_INSTANCE_NUMBER=2")
      end
    end

    describe '[:labels]' do
      let(:labels) { subject.to_hash[:labels] }

      it 'includes default service labels' do
        expect(labels).to include('io.kontena.service.id' => service.id.to_s)
        expect(labels).to include('io.kontena.service.name' => service.name)
        expect(labels).to include('io.kontena.stack.name' => service.stack.name)
        expect(labels).to include('io.kontena.grid.name' => grid.name)
      end

      it 'does not include load balancer labels by default' do
        expect(labels.keys).not_to include('io.kontena.load_balancer.name')
      end

      it 'includes load balancer labels if linked' do
        service.link_to(lb)
        expect(labels).to include('io.kontena.load_balancer.name' => lb.name)
        expect(labels).to include('io.kontena.load_balancer.internal_port' => '80')
        expect(labels).to include('io.kontena.load_balancer.mode' => 'http')
      end

      it 'includes health check labels if defined' do
        service.health_check = GridServiceHealthCheck.new(uri: '/', port: 80, protocol: 'http')
        expect(labels).to include('io.kontena.health_check.protocol' => 'http')
        expect(labels).to include('io.kontena.health_check.uri' => '/')
        expect(labels).to include('io.kontena.health_check.port' => '80')
        expect(labels).to include('io.kontena.health_check.interval' => '60')
        expect(labels).to include('io.kontena.health_check.timeout' => '10')
        expect(labels).to include('io.kontena.health_check.initial_delay' => '10')
      end

      it 'includes no health check labels if protocol nil' do
        service.health_check = GridServiceHealthCheck.new(uri: '/', port: 80)
        expect(labels).not_to include('io.kontena.health_check.protocol' => 'http')
        expect(labels).not_to include('io.kontena.health_check.uri' => '/')
        expect(labels).not_to include('io.kontena.health_check.port' => '80')
        expect(labels).not_to include('io.kontena.health_check.interval' => '60')
        expect(labels).not_to include('io.kontena.health_check.timeout' => '10')
        expect(labels).not_to include('io.kontena.health_check.initial_delay' => '10')
      end
    end
  end

  describe '#registry_name' do
    it 'returns DEFAULT_REGISTRY by default' do
      expect(subject.registry_name).to eq(Rpc::ServicePodSerializer::DEFAULT_REGISTRY)
    end

    it 'returns registry from image' do
      service.image_name = 'kontena.io/admin/redis:2.8'
      expect(subject.registry_name).to eq('kontena.io')
    end
  end
  describe '#build_volumes' do

    it 'adds volume specs' do
      expect(subject.build_volumes(1)).to eq([
        {:name=>"volA", :driver=>"local", :scope=>"node", :driver_opts=>{}},
        {:name=>"ext-vol", :driver=>"local", :scope=>"node", :driver_opts=>{}}
      ])
    end

    it 'doesn\'t add volumes when bind mounts used' do
      service.volumes = ['/host/path:/data']
      expect(subject.build_volumes(1)).to eq([])
    end

  describe '#image_credentials' do
    it 'return nil by default' do
      expect(subject.image_credentials).to be_nil
    end
  end

  describe '#remove_volume_flags' do
    it 'removes no flags as they are not present' do
      expect(subject.remove_volume_flags('volA:/data')).to eq('volA:/data')
    end

    it 'removes flags' do
      expect(subject.remove_volume_flags('/data:z:nocopy')).to eq('/data')
    end

    it 'removes mount flags' do
      expect(subject.remove_volume_flags('volA:/data:rprivate:ro')).to eq('volA:/data')
    end
  end
end

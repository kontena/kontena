require_relative '../../spec_helper'

describe Docker::ServiceCreator do
  let(:grid) { Grid.create!(name: 'test-grid', overlay_cidr: '10.81.0.0/23') }
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
      env: ['FOO=bar']
    )
  end

  let(:subject) { described_class.new(service, node) }

  before(:each) do
    10.times do |i|
      grid.overlay_cidrs.create!(ip: "10.81.1.#{i + 1}", subnet: '23')
    end
  end

  describe '#service_spec' do
    let(:service_spec) { subject.service_spec(2, 'rev') }

    it 'includes service_name' do
      expect(service_spec).to include(:service_name => 'app')
    end

    it 'includes instance_number' do
      expect(service_spec).to include(:instance_number => 2)
    end

    it 'includes image_name' do
      expect(service_spec).to include(:image_name => service.image_name)
    end

    it 'includes deploy_rev' do
      expect(service_spec).to include(:deploy_rev => 'rev')
    end

    it 'includes stateful' do
      expect(service_spec).to include(:stateful => false)
    end

    it 'includes user' do
      expect(service_spec).to include(:user => nil)
    end

    it 'includes cmd' do
      expect(service_spec).to include(:cmd => nil)
    end

    it 'includes memory' do
      expect(service_spec).to include(:memory => nil)
    end

    it 'includes memory_swap' do
      expect(service_spec).to include(:memory_swap => nil)
    end

    it 'includes cpu_shares' do
      expect(service_spec).to include(:cpu_shares => nil)
    end

    it 'includes privileged' do
      expect(service_spec).to include(:privileged => nil)
    end

    it 'includes cap_add' do
      expect(service_spec).to include(:cap_add => [])
    end

    it 'includes cap_drop' do
      expect(service_spec).to include(:cap_drop => [])
    end

    it 'includes devices' do
      expect(service_spec).to include(:devices => [])
    end

    it 'includes ports' do
      expect(service_spec).to include(:ports => [])
    end

    it 'includes volumes' do
      expect(service_spec).to include(:volumes => [])
    end

    it 'includes volumes_from' do
      expect(service_spec).to include(:volumes_from => [])
    end

    it 'includes net' do
      expect(service_spec).to include(:net => 'bridge')
    end

    it 'includes log_driver' do
      expect(service_spec).to include(:log_driver => nil)
    end

    it 'includes log_opts' do
      expect(service_spec).to include(:log_opts => {})
    end

    it 'includes hooks' do
      expect(service_spec).to include(:hooks => [])
    end

    it 'includes secrets' do
      expect(service_spec).to include(:secrets => [])
    end

    describe '[:env]' do
      let(:env) { service_spec[:env] }

      it 'includes saved env variable' do
        expect(env).to include('FOO=bar')
      end

      it 'includes default service variables' do
        expect(env).to include("KONTENA_SERVICE_ID=#{service.id.to_s}")
        expect(env).to include("KONTENA_SERVICE_NAME=#{service.name.to_s}")
        expect(env).to include("KONTENA_GRID_NAME=#{service.grid.name.to_s}")
        expect(env).to include("KONTENA_NODE_NAME=#{node.name.to_s}")
      end
    end

    describe '[:labels]' do
      let(:labels) { service_spec[:labels] }

      it 'includes default service labels' do
        expect(labels).to include('io.kontena.container.id' => anything)
        expect(labels).to include('io.kontena.service.id' => service.id.to_s)
        expect(labels).to include('io.kontena.service.name' => service.name)
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
    end
  end
end

require_relative '../../spec_helper'

describe Rpc::ServicePodSerializer do
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:node) { grid.create_node!('node-1', node_id: 'a') }
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
      service_volumes: [ServiceVolume.new(volume: volume, path:'/data'), ServiceVolume.new(volume: ext_vol, path: '/foo')],
      stop_grace_period: 20
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
    Volume.create(grid: grid, name: 'volA', scope: 'stack', driver: 'local')
  end

  let! :ext_vol do
    Volume.create(grid: grid, name: 'ext-vol', scope: 'instance', driver: 'local')
  end

  let! :domain_auth_dns do
    GridDomainAuthorization.create!(grid: grid, authorization_type: 'dns-01', grid_service: service, domain: 'kontena.io', tls_sni_certificate: 'DNS_AUTH')
  end

  let! :domain_auth_tls do
    GridDomainAuthorization.create!(grid: grid, authorization_type: 'tls-sni-01', grid_service: service, domain: 'www.kontena.io', tls_sni_certificate: 'TLS_AUTH')
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

    it 'includes shm_size' do
      expect(subject.to_hash).to include(:shm_size => nil)
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
      expect(subject.to_hash).to include(:volumes =>
        [
          {name: 'null.volA', path: '/data', flags: nil, driver: 'local', driver_opts: {}},
          {name: 'app.ext-vol-2', path: '/foo', flags: nil, driver: 'local', driver_opts: {}}
        ]
      )
    end

    it 'includes volumes_from' do
      expect(subject.to_hash).to include(:volumes_from => [])
    end

    it 'includes net' do
      expect(subject.to_hash).to include(:net => 'bridge')
    end

    it 'includes hostname' do
      expect(subject.to_hash).to include(:hostname => 'app-2')
    end

    it 'includes domainname' do
      expect(subject.to_hash).to include(:domainname => 'test-grid.kontena.local')
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
      expect(subject.to_hash[:secrets].size).to eq(1)
    end

    it 'includes default network' do
      expect(subject.to_hash).to include(:networks => [{name: 'kontena', subnet: '10.81.0.0/16', multicast: true, internal: false}])
    end

    it 'stop_grace_period' do
      expect(subject.to_hash).to include(:stop_grace_period => 20)
    end

    it 'includes domain auth as secret' do

      expect(subject.to_hash[:secrets].find { |s| s[:name] == 'SSL_CERTS'}[:value]).to eq('TLS_AUTH')
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
        expect(env).to include("KONTENA_PLATFORM_NAME=#{service.grid.name.to_s}")
        expect(env).to include("KONTENA_STACK_NAME=#{service.stack.name.to_s}")
        expect(env).to include("KONTENA_NODE_NAME=#{node.name.to_s}")
        expect(env).to include("KONTENA_SERVICE_INSTANCE_NUMBER=2")
      end
    end

    describe '[:secrets]' do
      it 'includes certificates as secrets' do
        Certificate.create!(grid: grid,
          subject: 'kontena.io',
          valid_until: Time.now + 90.days,
          private_key: 'private_key',
          certificate: 'certificate',
          chain: 'chain')
        service.certificates.create!(subject: 'kontena.io', name: 'CERT')
        subject = described_class.new(service_instance)
        secrets = subject.to_hash[:secrets]

        expect(secrets.size).to eq(2) # There's also the tls domain auth secret

        expect(secrets.find{ |s| s[:name] == 'CERT'}[:value]).to eq('certificatechainprivate_key')
      end
    end

    describe '[:labels]' do
      let(:labels) { subject.to_hash[:labels] }

      it 'includes default service labels' do
        expect(labels).to include('io.kontena.service.id' => service.id.to_s)
        expect(labels).to include('io.kontena.service.name' => service.name)
        expect(labels).to include('io.kontena.stack.name' => service.stack.name)
        expect(labels).to include('io.kontena.grid.name' => grid.name)
        expect(labels).to include('io.kontena.platform.name' => grid.name)
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
      expect(subject.build_volumes).to eq([
        {:name=>"null.volA", :path => '/data', :flags => nil, :driver=>"local", :driver_opts=>{}},
        {:name=>"app.ext-vol-2", :path => '/foo', :flags => nil, :driver=>"local", :driver_opts=>{}}
      ])
    end

    it 'adds bind mounts as volumes' do
      service.service_volumes = [ServiceVolume.new(bind_mount: '/host/path', path: '/data')]
      expect(subject.build_volumes).to eq([{:bind_mount=>"/host/path", :path => '/data', :flags => nil}])
    end

    it 'adds anon volume specs' do
      service.service_volumes = [ServiceVolume.new(path: '/data')]
      expect(subject.build_volumes).to eq([{:bind_mount=>nil, :path => '/data', :flags => nil}])
    end
  end

  describe '#image_credentials' do
    it 'return nil by default' do
      expect(subject.image_credentials).to be_nil
    end
  end

  describe '#build_hooks' do
    it 'returns not-executed oneshot hook' do
      hook = service.hooks.create!(
        type: 'post_start',
        cmd: 'sleep 1',
        oneshot: true
      )
      hooks = subject.build_hooks
      expect(hooks[0]).to eq({ id: hook.id.to_s, type: hook.type, cmd: hook.cmd, oneshot: hook.oneshot})
    end

    it 'does not return oneshot hooks that are already executed' do
      service.hooks.create(
        type: 'post_start',
        cmd: 'sleep 1',
        oneshot: true
      )
      service.hooks.first.push(:done => service_instance.instance_number.to_s)
      hooks = subject.build_hooks
      expect(hooks.size).to eq(0)
    end
  end
end

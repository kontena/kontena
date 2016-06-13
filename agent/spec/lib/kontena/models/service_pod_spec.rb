require_relative '../../../spec_helper'

describe Kontena::Models::ServicePod do

  let(:data) do
    {
      'service_name' => 'redis',
      'instance_number' => 2,
      'deploy_rev' => Time.now.utc.to_s,
      'updated_at' => Time.now.utc.to_s,
      'labels' => {
        'io.kontena.service.name' => 'redis-cache',
        'io.kontena.container.overlay_cidr' => '10.81.23.2/19'
      },
      'stateful' => true,
      'image_name' => 'redis:3.0',
      'user' => nil,
      'cmd' => nil,
      'entrypoint' => nil,
      'memory' => nil,
      'memory_swap' => nil,
      'cpu_shares' => nil,
      'privileged' => false,
      'cap_add' => nil,
      'cap_drop' => nil,
      'devices' => [],
      'ports' => [],
      'env' => [
        'KONTENA_SERVICE_NAME=redis-cache'
      ],
      'secrets' => [
          {'name' => 'PASSWD', 'value' => 'secret123', 'type' => 'env'}
      ],
      'volumes' => nil,
      'volumes_from' => nil,
      'net' => 'bridge',
      'log_driver' => nil
    }
  end

  let(:subject) { described_class.new(data) }

  describe '#overlay_network' do
    it 'returns overlay network information from labels' do
      expect(subject.overlay_network).to eq(data['labels']['io.kontena.container.overlay_cidr'])
    end

    it 'returns nil if overlay network information is not provided' do
      data['labels'] = {}
      expect(subject.overlay_network).to be_nil
    end
  end

  describe '#can_expose_ports?' do
    it 'returns true if overlay network is defined' do
      expect(subject.can_expose_ports?).to be_truthy
    end

    it 'returns false if overlay network is not provided' do
      data['labels'] = {}
      expect(subject.can_expose_ports?).to be_falsey
    end
  end

  describe '#stateless?' do
    it 'returns true if service is not marked stateful' do
      data['stateful'] = false
      expect(subject.stateless?).to be_truthy
    end

    it 'returns false if service is marked statelful' do
      data['stateful'] = true
      expect(subject.stateless?).to be_falsey
    end

    it 'returns true if service statefulness is unknown' do
      data['stateful'] = nil
      expect(subject.stateless?).to be_truthy
    end
  end

  describe '#stateful?' do
    it 'returns true if service is marked stateful' do
      data['stateful'] = true
      expect(subject.stateful?).to be_truthy
    end

    it 'returns false if service is not marked stateful' do
      data['stateful'] = false
    end

    it 'returns false if service statefulness is unknown' do
      data['stateful'] = nil
      expect(subject.stateful?).to be_falsey
    end
  end

  describe '#name' do
    it 'returns generated name' do
      expect(subject.name).to eq('redis-2')
    end
  end

  describe '#data_volume_name' do
    it 'returns generated name' do
      expect(subject.data_volume_name).to eq("#{subject.name}-volumes")
    end
  end

  describe '#service_config' do
    let(:service_config) { subject.service_config }

    it 'includes name' do
      data['name'] = 'redis-1'
      expect(service_config['name']).to eq('redis-2')
    end

    it 'includes Image' do
      expect(service_config['Image']).to eq(data['image_name'])
    end

    it 'includes HostName' do
      expect(service_config['HostName']).not_to be_nil
    end

    it 'does not include HostName if host network' do
      data['net'] = 'host'
      expect(service_config.has_key?('HostName')).to be_falsey
    end

    it 'includes Env' do
      expect(subject.service_config['Env']).to include('KONTENA_SERVICE_NAME=redis-cache')
    end

    it 'includes secrets in Env' do
      expect(subject.service_config['Env']).to include('PASSWD=secret123')
    end

    it 'includes secrets in Env with same key' do
      data['secrets'] << {'name' => 'SSL_CERTS', 'value' => 'foo', 'type' => 'env'}
      data['secrets'] << {'name' => 'SSL_CERTS', 'value' => 'bar', 'type' => 'env'}
      expect(subject.service_config['Env'].last).to eq("SSL_CERTS=foo\nbar")
    end

    it 'does not include user if nil' do
      expect(subject.service_config['User']).to be_nil
    end

    it 'includes User if set' do
      data['user'] = 'redis'
      expect(subject.service_config['User']).to eq('redis')
    end

    it 'does not include Cmd if nil' do
      expect(service_config['Cmd']).to be_nil
    end

    it 'includes Cmd if set' do
      data['cmd'] = 'redis'
      expect(service_config['Cmd']).to eq('redis')
    end

    it 'does not include Entrypoint if nil' do
      expect(service_config['Entrypoint']).to be_nil
    end

    it 'does not include Entrypoint if nil' do
      data['entrypoint'] = ['/bin/sh']
      expect(service_config['Entrypoint']).to eq(['/bin/sh'])
    end

    it 'includes empty ExposedPorts if no ports are defined' do
      expect(service_config['ExposedPorts']).to eq({})
    end

    it 'does not include ExposedPorts if ports are defined but network mode is not bridge' do
      data['ports'] = [
        {'container_port' => '2379', 'node_port' => '2379', 'protocol' => 'tcp'}
      ]
      data['net'] = 'host'
      expect(service_config['ExposedPorts']).to be_nil
    end

    it 'includes ExposedPorts if ports are defined' do
      data['ports'] = [
        {'container_port' => '2379', 'node_port' => '2379', 'protocol' => 'tcp'}
      ]
      expect(service_config['ExposedPorts'].empty?).to be_falsey
    end

    it 'does not include Volumes if no volumes are defined' do
      expect(service_config['Volumes']).to be_nil
    end

    it 'does not include Volumes if volumes are defined and service is stateful' do
      data['volumes'] = ['/data']
      expect(service_config['Volumes']).to be_nil
    end

    it 'includes Volumes if volumes are defined and service is stateless' do
      data['stateful'] = false
      data['volumes'] = ['/data']
      expect(service_config['Volumes']).not_to be_nil
    end

    it 'includes Labels' do
      expect(service_config['Labels'])
    end

    it 'includes HostConfig' do
      expect(service_config['HostConfig']).not_to be_nil
    end
  end

  describe '#service_host_config' do
    let(:host_config) { subject.service_host_config }

    it 'does not include Binds if no volumes are defined' do
      expect(host_config['Binds']).to be_nil
    end

    it 'does include Binds if binded volumes are defined' do
      data['volumes'] = ['/data:/data']
      expect(host_config['Binds']).not_to be_nil
    end

    it 'does not include VolumesFrom if they are not defined' do
      expect(host_config['VolumesFrom']).to be_nil
    end

    it 'include VolumesFrom if they are defined' do
      data['volumes_from'] = ['data']
      expect(host_config['VolumesFrom']).not_to be_nil
    end

    it 'does not include PortBindings if no ports are defined' do
      expect(host_config['PortBindings']).to eq({})
    end

    it 'includes PortBindings if ports are defined' do
      data['ports'] = [
        {'container_port' => '2379', 'node_port' => '2379', 'protocol' => 'tcp'}
      ]
      expect(host_config['PortBindings'].empty?).to be_falsey
    end

    it 'sets NetworkMode' do
      data['net'] = 'host'
      expect(host_config['NetworkMode']).to eq('host')
    end

    it 'does not include CpuShares if not defined' do
      expect(host_config['CpuShares']).to be_nil
    end

    it 'includes CpuShares if set' do
      data['cpu_shares'] = 500
      expect(host_config['CpuShares']).to eq(500)
    end

    it 'sets PidMode if set' do
      data['pid'] = 'host'
      expect(host_config['PidMode']).to eq('host')
    end
  end

  describe '#build_exposed_ports' do
    let(:ports) do
      [
        {'container_port' => 2379, 'node_port' => 12379, 'protocol' => 'tcp'},
        {'container_port' => 1194, 'node_port' => 1194, 'protocol' => 'udp'},
      ]
    end

    it 'returns empty hash if no ports are defined' do
      expect(subject.build_exposed_ports).to eq({})
    end

    it 'returns correct hash when ports are defined' do
      data['ports'] = ports
      exposed_ports = subject.build_exposed_ports
      expect(exposed_ports['2379/tcp']).to eq({})
      expect(exposed_ports['1194/udp']).to eq({})
    end
  end

  describe '#build_port_bindings' do
    let(:ports) do
      [
        {'ip' => '1.2.3.4', 'container_port' => 2379, 'node_port' => 12379, 'protocol' => 'tcp'},
        {'container_port' => 1194, 'node_port' => 1194, 'protocol' => 'udp'},
      ]
    end

    it 'returns empty hash when no ports are defined' do
      expect(subject.build_port_bindings).to eq({})
    end

    it 'retuns correct hash when ports are defined' do
      data['ports'] = ports
      port_bindings = subject.build_port_bindings
      expect(port_bindings['2379/tcp']).to eq([{'HostIp' => '1.2.3.4', 'HostPort' => '12379'}])
      expect(port_bindings['1194/udp']).to eq([{'HostIp' => '0.0.0.0', 'HostPort' => '1194'}])
    end
  end

  describe '#build_volumes' do
    let(:volumes) do
      ['/proc:/host/proc:ro', '/data']
    end

    it 'returns empty hash when no volumes are defined' do
      expect(subject.build_volumes).to eq({})
    end

    it 'returns correct hash when volumes are defined' do
      data['volumes'] = volumes
      vols = subject.build_volumes
      expect(vols['/host/proc']).to eq({})
      expect(vols['/data']).to eq({})
    end
  end

  describe '#build_bind_volumes' do
    let(:volumes) do
      ['/proc:/host/proc:ro', '/data']
    end

    it 'returns empty array when no volumes are defined' do
      expect(subject.build_bind_volumes).to eq([])
    end

    it 'returns correct array when volumes are defined' do
      data['volumes'] = volumes
      bind_vols = subject.build_bind_volumes
      expect(bind_vols.size).to eq(1)
      expect(bind_vols[0]).to eq('/proc:/host/proc:ro')
    end
  end

  describe '#build_device_opts' do
    let(:devices) do
      ['/dev/fuse', '/dev/audio:/dev/audio2:rw']
    end

    it 'returns empty array when no devices are defined' do
      expect(subject.build_device_opts).to eq([])
    end

    it 'returns correct array when devices are defined' do
      data['devices'] = devices
      device_opts = subject.build_device_opts
      expect(device_opts.size).to eq(2)
      expect(device_opts[0]).to eq({
        'PathOnHost' => '/dev/fuse',
        'PathInContainer' => '/dev/fuse',
        'CgroupPermissions' => 'rwm'
      })
      expect(device_opts[1]).to eq({
        'PathOnHost' => '/dev/audio',
        'PathInContainer' => '/dev/audio2',
        'CgroupPermissions' => 'rw'
      })
    end
  end

  describe '#build_log_opts' do
    it 'returns empty hash when no log driver is defined' do
      expect(subject.build_log_opts).to eq({})
    end

    it 'retuns correct hash when log driver is defined' do
      data['log_driver'] = 'fluentd'
      expect(subject.build_log_opts).to eq({
        'Type' => 'fluentd',
        'Config' => {}
      })
    end

    it 'returns correct hash when log driver and opts is defined' do
      data['log_driver'] = 'fluentd'
      data['log_opts'] = {'foo' => 'bar'}
      expect(subject.build_log_opts).to eq({
        'Type' => 'fluentd',
        'Config' => {
          'foo' => 'bar'
        }
      })
    end
  end
end

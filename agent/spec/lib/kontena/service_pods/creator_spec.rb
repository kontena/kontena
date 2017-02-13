
describe Kontena::ServicePods::Creator do

  let(:data) do
    {
      'service_id' => 'aa',
      'service_name' => 'redis',
      'instance_number' => 2,
      'deploy_rev' => Time.now.utc.to_s,
      'updated_at' => Time.now.utc.to_s,
      'labels' => {
        'io.kontena.service.id' => 'aa',
        'io.kontena.service.instance_number' => '2',
        'io.kontena.service.name' => 'redis-cache',
        'io.kontena.container.overlay_cidr' => '10.81.23.2/19'
      },
      'stateful' => true,
      'image_name' => 'redis:3.0',
      'devices' => [],
      'ports' => [],
      'env' => [
        'KONTENA_SERVICE_NAME=redis-cache'
      ],
      'net' => 'bridge',
      'volume_specs' => [{'name' => 'someVolume', 'driver' => 'local', 'driver_opts' => {'foo' => 'bar'}}]
    }
  end

  let(:service_pod) { Kontena::Models::ServicePod.new(data) }
  let(:subject) { described_class.new(service_pod) }

  describe '#ensure_data_container' do
    it 'creates data container if it does not exist' do
      allow(subject).to receive(:get_container).and_return(nil)
      expect(subject).to receive(:create_container).with(service_pod.data_volume_config)
      subject.ensure_data_container(service_pod)
    end
  end

  describe '#ensure_volumes' do
    it 'creates volume if not found' do
      expect(Docker::Volume).to receive(:get).with('someVolume').and_raise(Docker::Error::NotFoundError)
      expect(Docker::Volume).to receive(:create)
      subject.ensure_volumes(service_pod)
    end

    it 'does not create volume if found' do
      expect(Docker::Volume).to receive(:get).with('someVolume').and_return(double())
      expect(Docker::Volume).not_to receive(:create)
      subject.ensure_volumes(service_pod)
    end
  end

  describe '#get_container' do
    it 'gets container from docker' do
      expect(Docker::Container).to receive(:all).and_return([])
      subject.get_container('service_id', 2)
    end
  end

  describe '#service_uptodate?' do
    it 'returns false if image name changes' do
      service_container = spy(:service_container, config: {
        'Image' => 'foo/bar:latest'
      })
      expect(subject.service_uptodate?(service_container)).to be_falsey
    end

    it 'returns false if image does not exist' do
      service_container = spy(:service_container,
        info: {
          'Created' => Time.now.utc.to_s
        },
        config: {
          'Image' => service_pod.image_name
        }
      )
      allow(Docker::Image).to receive(:get).and_return(nil)
      expect(subject.service_uptodate?(service_container)).to be_falsey
    end

    it 'returns false if container created_at is less than service_pod updated_at' do
      service_container = spy(:service_container,
        info: {
          'Created' => (Time.now.utc - 60).to_s
        },
        config: {
          'Image' => service_pod.image_name
        }
      )
      expect(subject.service_uptodate?(service_container)).to be_falsey
    end

    it 'returns true if container & image are uptodate' do
      service_container = spy(:service_container,
        info: {
          'Created' => (Time.now.utc + 2).to_s
        },
        config: {
          'Image' => service_pod.image_name
        },
        labels: {}
      )
      allow(Docker::Image).to receive(:get).and_return(spy(:image, info: {
        'Created' => (Time.now.utc + 1).to_s
      }))
      expect(subject.service_uptodate?(service_container)).to be_truthy
    end
  end

  describe '#recreate_service_container?' do
    it 'returns false if RestartPolicy=no' do
      service_container = spy(:service_container,
        state: {},
        restart_policy: {'Name' => 'no'}
      )
      expect(subject.recreate_service_container?(service_container)).to be_falsey
    end

    it 'returns false if container is running' do
      service_container = spy(:service_container,
        state: {'Running' => true},
        restart_policy: {'Name' => 'always'}
      )
      expect(subject.recreate_service_container?(service_container)).to be_falsey
    end

    it 'returns false if RestartPolicy=always and container is stopped without error message' do
      service_container = spy(:service_container,
        state: {'Running' => false, 'Error' => ''},
        restart_policy: {'Name' => 'always'}
      )
      expect(subject.recreate_service_container?(service_container)).to be_falsey
    end

    it 'returns true if RestartPolicy=always and container is stopped with error message' do
      service_container = spy(:service_container,
        autostart?: true, running?: false,
        state: {'Running' => false, 'Error' => 'oh noes'}
      )
      expect(subject.recreate_service_container?(service_container)).to be_truthy
    end
  end

  describe '#config_container' do
    let(:network_adapter) { instance_double(Kontena::NetworkAdapters::Weave) }

    before(:each) do
      allow(subject).to receive(:network_adapter).and_return(network_adapter)
    end

    context "For a net=host ServicePod" do
      let(:service_pod) {
        Kontena::Models::ServicePod.new(
          'service_id' => 'aa',
          'service_name' => 'redis',
          'instance_number' => 2,
          'deploy_rev' => Time.now.utc.to_s,
          'updated_at' => Time.now.utc.to_s,
          'labels' => {
            'io.kontena.service.id' => 'aa',
            'io.kontena.service.instance_number' => '2',
            'io.kontena.service.name' => 'redis-cache',
          },
          'stateful' => true,
          'image_name' => 'redis:3.0',
          'devices' => [],
          'ports' => [],
          'env' => [
            'KONTENA_SERVICE_NAME=redis-cache'
          ],
          'net' => 'host',
          'domainname' => 'testgrid.kontena.local'
        )
      }

      subject { described_class.new(service_pod) }

      it 'does not include weave-wait' do
        expect(network_adapter).to_not receive(:modify_create_opts)

        config = subject.config_container(service_pod)

        expect(config.dig('HostConfig', 'NetworkMode')).to eq('host')
        expect(config.dig('Entrypoint')).to be_nil
      end
    end

    describe '#labels_outdated?' do
      it 'returns true when labels are outdated' do
        service_container = spy(:service_container,
          labels: { 'io.kontena.load_balancer.name' => 'lb'}
        )
        expect(subject.labels_outdated?({}, service_container)).to be_truthy
        expect(subject.labels_outdated?({ 'io.kontena.load_balancer.name' => 'lb2'}, service_container)).to be_truthy
      end

      it 'returns false with empty labels' do
        service_container = spy(:service_container,
          labels: {}
        )
        expect(subject.labels_outdated?({}, service_container)).to be_falsey
      end

      it 'returns false with up-to-date labels' do
        service_container = spy(:service_container,
          labels: { 'io.kontena.load_balancer.name' => 'lb'}
        )
        expect(subject.labels_outdated?({ 'io.kontena.load_balancer.name' => 'lb'}, service_container)).to be_falsey
      end
    end

    context "For a net=bridge ServicePod" do
      let(:service_pod) {
        Kontena::Models::ServicePod.new(
          'service_id' => 'aa',
          'service_name' => 'redis',
          'instance_number' => 2,
          'deploy_rev' => Time.now.utc.to_s,
          'updated_at' => Time.now.utc.to_s,
          'labels' => {
            'io.kontena.service.id' => 'aa',
            'io.kontena.service.instance_number' => '2',
            'io.kontena.service.name' => 'redis-cache',
          },
          'stateful' => true,
          'image_name' => 'redis:3.0',
          'devices' => [],
          'ports' => [],
          'env' => [
            'KONTENA_SERVICE_NAME=redis-cache'
          ],
          'net' => 'bridge',
          'domainname' => 'testgrid.kontena.local'
        )
      }

      subject { described_class.new(service_pod) }

      it 'does not include weave-wait' do
        expect(network_adapter).to receive(:modify_create_opts)

        config = subject.config_container(service_pod)

      end
    end
  end
end

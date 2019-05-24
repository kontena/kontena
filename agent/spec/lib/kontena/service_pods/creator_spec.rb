
describe Kontena::ServicePods::Creator do

  let(:pod_secrets) { nil }
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
      'stateful' => false,
      'image_name' => 'redis:3.0',
      'devices' => [],
      'ports' => [],
      'env' => [
        'KONTENA_SERVICE_NAME=redis-cache'
      ],
      'secrets' => pod_secrets,
      'net' => 'bridge',
      'volumes' => [
        {'name' => 'someVolume', 'path' => '/data', 'driver' => 'local', 'driver_opts' => {}}
      ]
    }
  end

  let(:service_pod) { Kontena::Models::ServicePod.new(data) }
  let(:hook_manager) { double(:hook_manager) }
  let(:subject) { described_class.new(service_pod, hook_manager) }

  before(:each) do
    allow(hook_manager).to receive(:track)
  end

  describe '#ensure_data_container' do
    it 'creates data container if it does not exist' do
      allow(subject).to receive(:get_container).and_return(nil)
      expect(subject).to receive(:create_container).with(service_pod.data_volume_config)
      subject.ensure_data_container(service_pod)
    end
  end

  describe '#get_container' do
    it 'gets container from docker' do
      expect(Docker::Container).to receive(:all).and_return([])
      subject.get_container('service_id', 2)
    end
  end

  describe '#perform' do
    before do
      expect(subject).to receive(:ensure_image).with('redis:3.0')
      allow(subject).to receive(:wait_until!)

    end

    context 'for a pod with oversize envs' do
      let(:pod_secrets) { (1..128).map{|i|
        {
          'name' => "SSL_CERTS",
          'type' => 'env',
          'value' => 'A' * 1024,
        }
      } }

      context 'with an existing stateless container' do
        let(:container) { instance_double(Docker::Container) }

        before do
          allow(subject).to receive(:get_container).with('aa', 2, 'volume').and_return(nil)
          allow(subject).to receive(:get_container).with('aa', 2).and_return(container)
        end

        it 'fails before cleaning up the old container' do
          expect(subject).to_not receive(:cleanup_container)
          expect(subject).to_not receive(:create_container)

          expect{subject.perform}.to raise_error(Kontena::Models::ServicePod::ConfigError, 'Env SSL_CERTS is too large at 131209 bytes')
        end
      end
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

      subject { described_class.new(service_pod, hook_manager) }

      it 'does not include weave-wait' do
        expect(network_adapter).to_not receive(:modify_container_opts)

        config = subject.config_container(service_pod)

        expect(config.dig('HostConfig', 'NetworkMode')).to eq('host')
        expect(config.dig('Entrypoint')).to be_nil
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

      subject { described_class.new(service_pod, hook_manager) }

      it 'includes weave-wait' do
        expect(network_adapter).to receive(:modify_container_opts)

        config = subject.config_container(service_pod)

      end
    end
  end
end

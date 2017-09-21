
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
        expect(network_adapter).to_not receive(:modify_create_opts)

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

      it 'does not include weave-wait' do
        expect(network_adapter).to receive(:modify_create_opts)

        config = subject.config_container(service_pod)

      end
    end
  end
end


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
  let(:subject) { described_class.new(service_pod) }

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

end

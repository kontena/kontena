describe Kontena::NetworkAdapters::ContainerConfigurer, :celluloid => true do
  let(:ipam_client) { instance_double(Kontena::NetworkAdapters::IpamClient) }

  let(:network_observable) { instance_double(Kontena::Observable) }
  let(:network_state) { {
      ipam_pool: 'kontena',
      ipam_subnet: '10.81.0.0/16',
  } }

  before do
    allow(subject).to receive(:ipam_client).and_return(ipam_client)
    allow(subject).to receive(:network_observable).and_return(network_observable)
    allow(subject).to receive(:observe).with(network_observable).and_return(network_state)
  end

  describe '#configure' do
    let(:image) { 'test/test' }
    let(:volumes_from) { [] }
    let(:image_info) { {
        'Config' => {

        },
    } }
    let(:container_opts) { {
        'name' => 'test',
        'Image' => image,
        'HostConfig' => {
          'NetworkMode' => 'bridge',
          'VolumesFrom' => volumes_from,
        },
        'Labels' => {
          'io.kontena.test' => '1',
        },
    } }
    subject { described_class.new(container_opts) }
    let(:ipam_response) { {'Address' => '10.81.128.6/16'} }

    before do
      allow(Docker::Image).to receive(:get).with(image).and_return(double(info: image_info))

      allow(subject).to receive(:interface_ip).with('docker0').and_return(bridge_ip)

      allow(ipam_client).to receive(:reserve_address).with('kontena').and_return(ipam_response)
    end

    it 'adds weavewait to empty VolumesFrom' do
      expect(subject.configure['HostConfig']['VolumesFrom']).to eq ['weavewait-1.9.3:ro']
    end

    it 'adds dns settings' do
      expect(subject.configure['HostConfig']['Dns']).to eq [bridge_ip]
    end

    it 'adds ipam labels' do
      expect(subject.configure['Labels']).to eq(
        'io.kontena.test' => '1',
        'io.kontena.container.overlay_network' => 'kontena',
        'io.kontena.container.overlay_cidr' => '10.81.128.6/16',
      )
    end

    context 'with VolumesFrom' do
      let(:volumes_from) { ['test-data'] }

      it 'adds weavewait to non-empty VolumesFrom' do
        expect(subject.configure['HostConfig']['VolumesFrom']).to eq ['test-data', 'weavewait-1.9.3:ro']
      end
    end
  end
end

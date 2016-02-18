require_relative '../../../spec_helper'

describe Kontena::Rpc::DockerContainerApi do

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  let(:image) { double(:image, info: {
    'Config' => {
      'Cmd' => ["nginx", "-g", "daemon off;"]
    }
  })}

  before(:each) do
    allow(subject.overlay_adapter).to receive(:ensure_weave_wait)
    allow(Docker::Image).to receive(:get).with('nginx:latest').and_return(image)
  end

  describe '#create' do
    it 'sets entrypoint to weavewait' do
      expect(Docker::Container).to receive(:create).with({
        'Image' => 'nginx:latest',
        'Entrypoint' => ['/w/w'],
        'Cmd' => image.info['Config']['Cmd'],
        'HostConfig' => hash_including('VolumesFrom' => ['weavewait:ro'])
      }).and_return(spy(:container))
      opts = {
        'Image' => 'nginx:latest'
      }
      subject.create(opts)
    end
  end
end

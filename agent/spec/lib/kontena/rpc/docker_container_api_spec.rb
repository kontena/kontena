require_relative '../../../spec_helper'

describe Kontena::Rpc::DockerContainerApi do

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
        'Entrypoint' => ['/w/w', '-s'],
        'Cmd' => image.info['Config']['Cmd']
      }).and_return(spy(:container))
      opts = {
        'Image' => 'nginx:latest'
      }
      subject.create(opts)
    end
  end
end

require_relative '../../spec_helper'

describe Kontena::WeaveAdapter do

  before(:each) do
    allow(subject).to receive(:ensure_weave_wait).and_return(true)
  end

  describe '#modify_host_config' do
    it 'adds weavewait to empty VolumesFrom' do
      opts = {}
      subject.modify_host_config(opts)
      expect(opts['HostConfig']['VolumesFrom']).to include('weavewait:ro')
    end

    it 'adds weavewait to non-empty VolumesFrom' do
      opts = {
        'VolumesFrom' => ['foobar-data']
      }
      subject.modify_host_config(opts)
      expect(opts['HostConfig']['VolumesFrom']).to include('weavewait:ro')
    end
  end
end

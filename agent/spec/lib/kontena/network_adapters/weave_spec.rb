require_relative '../../../spec_helper'

describe Kontena::NetworkAdapters::Weave do

  let(:bridge_ip) { '172.42.1.1' }
  let(:subject) { described_class.new(false) }

  before(:each) do
    Celluloid.boot
    allow(subject.wrapped_object).to receive(:ensure_weave_wait).and_return(true)
    allow(subject.wrapped_object).to receive(:interface_ip).and_return(bridge_ip)
  end

  after(:each) { Celluloid.shutdown }

  describe '#adapter_container' do
    it 'returns true if weave exec container' do
      container = spy(:container, :config => {'Image' => 'weaveworks/weaveexec:latest'})
      expect(subject.adapter_container?(container)).to be_truthy
    end

    it 'returns false if not weave exec container' do
      container = spy(:container, :config => {'Image' => 'redis:latest'})
      expect(subject.adapter_container?(container)).to be_falsey
    end
  end

  describe '#running?' do
    it 'returns true if weave is running' do
      weave = spy(:weave, :running? => true)
      allow(Docker::Container).to receive(:get).with('weave').and_return(weave)
      expect(subject.running?).to be_truthy
    end

    it 'returns false if weave is not running' do
      weave = spy(:weave, :running? => false)
      allow(Docker::Container).to receive(:get).with('weave').and_return(weave)
      expect(subject.running?).to be_falsey
    end

    it 'returns false if weave does not exist' do
      weave = spy(:weave, :running? => false)
      allow(Docker::Container).to receive(:get).with('weave') {
        raise Docker::Error::NotFoundError.new
      }
      expect(subject.running?).to be_falsey
    end
  end

  describe '#modify_host_config' do

    let(:weavewait) { "weavewait-#{described_class::WEAVE_VERSION}:ro"}

    it 'adds weavewait to empty VolumesFrom' do
      opts = {}
      subject.modify_host_config(opts)
      expect(opts['HostConfig']['VolumesFrom']).to include(weavewait)
    end

    it 'adds weavewait to non-empty VolumesFrom' do
      opts = {
        'VolumesFrom' => ['foobar-data']
      }
      subject.modify_host_config(opts)
      expect(opts['HostConfig']['VolumesFrom']).to include(weavewait)
    end

    it 'adds dns settings' do
      opts = {}
      subject.modify_host_config(opts)
      expect(opts['HostConfig']['Dns']).to include(bridge_ip)
    end

    it 'does not add dns settings when NetworkMode=host' do
      opts = {
        'HostConfig' => {
          'NetworkMode' => 'host'
        }
      }
      subject.modify_host_config(opts)
      expect(opts['HostConfig']['Dns']).to be_nil
    end
  end
end

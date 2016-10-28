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

  describe '#config_changed?' do
    let(:valid_image) do
      "#{Kontena::NetworkAdapters::Weave::WEAVE_IMAGE}:#{Kontena::NetworkAdapters::Weave::WEAVE_VERSION}"
    end

    it 'returns false if config is the same' do
      config = {
        'grid' => {
          'trusted_subnets' => []
        }
      }
      weave_config = {
        'Image' => valid_image,
        'Cmd' => ['--trusted-subnets', '']
      }
      weave = double(:weave, config: weave_config, restart_policy: {'Name' => 'no'})
      expect(subject.config_changed?(weave, config)).to be_falsey
    end

    it 'returns true if image version is not same' do
      config = {
        'grid' => {
          'trusted_subnets' => []
        }
      }
      weave_config = {
        'Image' => "#{Kontena::NetworkAdapters::Weave::WEAVE_IMAGE}:1.5.0",
        'Cmd' => ['--trusted-subnets', '']
      }

      weave = double(:weave, config: weave_config, restart_policy: {'Name' => 'no'})
      expect(subject.config_changed?(weave, config)).to be_truthy
    end

    it 'returns true if trusted-subnets is not same' do
      config = {
        'grid' => {
          'trusted_subnets' => ['10.1.2.0/16']
        }
      }
      weave_config = {
        'Image' => valid_image,
        'Cmd' => ['--trusted-subnets', '']
      }

      weave = double(:weave, config: weave_config, restart_policy: {'Name' => 'no'})
      expect(subject.config_changed?(weave, config)).to be_truthy
    end

    it 'returns true if restart policy does not match' do
      config = {
        'grid' => {
          'trusted_subnets' => []
        }
      }
      weave_config = {
        'Image' => valid_image,
        'Cmd' => ['--trusted-subnets', '']
      }

      weave = double(:weave, config: weave_config, restart_policy: {'Name' => 'always'})
      expect(subject.config_changed?(weave, config)).to be_truthy
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

  describe '#on_container_event' do
    it 'checks weave container on kill' do
      weave = double(:weave, name: '/weave', running?: true)
      event = double(:event, id: 'weave', status: 'kill')
      allow(Docker::Container).to receive(:get).with('weave').and_return(weave)
      expect(subject.wrapped_object).to receive(:heal_weave).with(weave)
      subject.on_container_event('topic', event)
    end

    it 'checks weave container on destroy' do
      weave = double(:weave, name: '/weave', running?: true)
      event = double(:event, id: 'weave', status: 'destroy')
      allow(Docker::Container).to receive(:get).with('weave').and_return(weave)
      expect(subject.wrapped_object).to receive(:heal_weave).with(weave)
      subject.on_container_event('topic', event)
    end

    it 'does not check weave container on start' do
      weave = double(:weave, name: '/weave', running?: true)
      event = double(:event, id: 'weave', status: 'start')
      allow(Docker::Container).to receive(:get).with('weave').and_return(weave)
      expect(subject.wrapped_object).not_to receive(:heal_weave).with(weave)
      subject.on_container_event('topic', event)
    end

    it 'does not check weave when event is from other container' do
      container = double(:con, name: 'other')
      event = double(:event, id: 'other', status: 'die')
      allow(Docker::Container).to receive(:get).with('other').and_return(container)
      expect(subject.wrapped_object).not_to receive(:heal_weave)
      subject.on_container_event('topic', event)
    end
  end

  describe '#heal_weave' do
    it 'calls start only if healing is not in progress' do
      weave = double(:weave, name: 'weave', running?: false)
      expect(subject.wrapped_object).to receive(:start).once
      subject.heal_weave(weave)
      allow(subject.wrapped_object).to receive(:healing?).and_return(true)
      subject.heal_weave(weave)
    end
  end
end

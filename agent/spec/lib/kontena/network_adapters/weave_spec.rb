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
      weave = double(:weave, config: weave_config)
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

      weave = double(:weave, config: weave_config)
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

      weave = double(:weave, config: weave_config)
      expect(subject.config_changed?(weave, config)).to be_truthy
    end
  end

  describe '#modify_host_config' do
    
    it 'adds dns settings' do
      opts = {}
      subject.modify_host_config(opts)
      expect(opts['HostConfig']['Dns']).to include(bridge_ip)
      expect(opts['HostConfig']['DnsOptions']).to include('use-vc')
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

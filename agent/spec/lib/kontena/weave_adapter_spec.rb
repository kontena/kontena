require_relative '../../spec_helper'

describe Kontena::WeaveAdapter do

  before(:each) do
    allow(subject).to receive(:ensure_weave_wait).and_return(true)
  end

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

    let(:bridge_ip) { '172.42.1.1' }

    before(:each) do
      expect(subject).to receive(:interface_ip).and_return(bridge_ip)
    end

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

  describe '#resolve_peer_ips' do
    it 'returns empty array by default' do
      expect(subject.resolve_peer_ips({})).to eq([])
    end

    it 'returns peer_ips from info' do
      peer_ips = ['192.168.22.13', '192.168.22.14']
      info = {'peer_ips' => peer_ips}
      expect(subject.resolve_peer_ips(info)).to eq(peer_ips)
    end

    it 'returns custom_peer_ips if they are set' do
      allow(ENV).to receive(:[]).with('WEAVE_CUSTOM_PEERS').and_return('10.12.0.23,10.12.0.24')
      peer_ips = ['192.168.22.13', '192.168.22.14']
      info = {'peer_ips' => peer_ips}
      expect(subject.resolve_peer_ips(info)).to eq(['10.12.0.23', '10.12.0.24'])
    end
  end

  describe '#expose_bridge' do
    it 'calls exec with correct ip' do
      info = {'node_number' => 2}
      ip = "10.81.0.2/19"
      expect(subject).to receive(:exec).with(['--local', 'expose', "ip:#{ip}"])
      subject.expose_bridge(info)
    end
  end

  describe '#custom_peer_ips' do
    it 'returns nil by default' do
      expect(subject.custom_peer_ips).to be_nil
    end

    it 'returns custom peers from WEAVE_CUSTOM_PEERS env' do
      allow(ENV).to receive(:[]).with('WEAVE_CUSTOM_PEERS').and_return('192.168.22.13')
      expect(subject.custom_peer_ips).to eq(['192.168.22.13'])
    end
  end
end

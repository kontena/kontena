
describe Kontena::NetworkAdapters::Weave do

  let(:bridge_ip) { '172.42.1.1' }
  let(:subject) { described_class.new(false) }

  before(:each) do
    Celluloid.boot
    allow(subject.wrapped_object).to receive(:ensure_weave_wait).and_return(true)
    allow(subject.wrapped_object).to receive(:interface_ip).and_return(bridge_ip)
  end

  after(:each) { Celluloid.shutdown }

  describe '#terminate' do
    it 'terminates also executor pool if it is still alive' do
      pool = double
      expect(Kontena::NetworkAdapters::WeaveExecutor).to receive(:pool).and_return(pool)
      expect(pool).to receive(:alive?).and_return(true)
      expect(pool).to receive(:terminate)
      subject = described_class.new(false)
      subject.terminate
    end

    it 'does not attempt to terminate dead pool' do
      pool = double
      expect(Kontena::NetworkAdapters::WeaveExecutor).to receive(:pool).and_return(pool)
      expect(pool).to receive(:alive?).and_return(false)
      expect(pool).not_to receive(:terminate)
      subject = described_class.new(false)
      subject.terminate
    end
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

  describe '#weave_container_running?' do
    it 'returns false if weave does not exist' do
      weave = spy(:weave, :running? => false)
      allow(Docker::Container).to receive(:get).with('weave') {
        raise Docker::Error::NotFoundError.new
      }
      expect(subject.weave_container_running?).to be_falsey
    end

    it 'returns false if weave is not running' do
      weave = spy(:weave, :running? => false)
      allow(Docker::Container).to receive(:get).with('weave').and_return(weave)
      expect(subject.weave_container_running?).to be_falsey
    end

    it 'returns true if weave is not running' do
      weave = spy(:weave, :running? => true)
      allow(Docker::Container).to receive(:get).with('weave').and_return(weave)
      expect(subject.weave_container_running?).to be_truthy
    end
  end

  describe '#running?' do
    it 'return false if weave container not running' do
      expect(subject.wrapped_object).to receive(:weave_container_running?).and_return(false)
      expect(subject.running?).to be_falsey
    end

    it 'return false if weave container running but weave api not ready' do
      expect(subject.wrapped_object).to receive(:weave_container_running?).and_return(true)
      expect(subject.wrapped_object).to receive(:weave_api_ready?).and_return(false)
      expect(subject.running?).to be_falsey
    end


    it 'return false if weave container and weave api running but weave bridge not configured' do
      expect(subject.wrapped_object).to receive(:weave_container_running?).and_return(true)
      expect(subject.wrapped_object).to receive(:weave_api_ready?).and_return(true)
      expect(subject.wrapped_object).to receive(:interface_ip).and_return(nil)
      expect(subject.running?).to be_falsey
    end

    it 'returns true only if all components running' do
      expect(subject.wrapped_object).to receive(:weave_container_running?).and_return(true)
      expect(subject.wrapped_object).to receive(:weave_api_ready?).and_return(true)
      expect(subject.wrapped_object).to receive(:interface_ip).and_return('10.81.0.1')
      expect(subject.running?).to be_truthy
    end
  end

  describe '#network_ready?' do
    let :ipam_plugin_launcher do
      instance_double(Kontena::Launchers::IpamPlugin)
    end

    before do
      allow(Celluloid::Actor).to receive(:[]).with(:ipam_plugin_launcher).and_return(ipam_plugin_launcher)
    end

    it 'return false is weave not running' do
      expect(subject.wrapped_object).to receive(:running?).and_return(false)
      expect(subject.network_ready?).to be_falsey
    end

    it 'return false is weave running but ipam not' do
      expect(subject.wrapped_object).to receive(:running?).and_return(true)
      expect(ipam_plugin_launcher).to receive(:running?).and_return(false)
      expect(subject.network_ready?).to be_falsey
    end

    it 'return true is weave and ipam running' do
      expect(subject.wrapped_object).to receive(:running?).and_return(true)
      expect(ipam_plugin_launcher).to receive(:running?).and_return(true)
      expect(subject.network_ready?).to be_truthy
    end
  end

  describe '#config_changed?' do
    let(:valid_image) do
      "#{Kontena::NetworkAdapters::Weave::WEAVE_IMAGE}:#{Kontena::NetworkAdapters::Weave::WEAVE_VERSION}"
    end

    it 'returns false if config is the same' do
      node = Node.new(
        'grid' => {
          'trusted_subnets' => []
        }
      )
      weave_config = {
        'Image' => valid_image,
        'Cmd' => ['--trusted-subnets', '', '--conn-limit', '0']
      }
      weave = double(:weave, config: weave_config)
      expect(subject.config_changed?(weave, node)).to be_falsey
    end

    it 'returns true if image version is not same' do
      node = Node.new(
        'grid' => {
          'trusted_subnets' => []
        }
      )
      weave_config = {
        'Image' => "#{Kontena::NetworkAdapters::Weave::WEAVE_IMAGE}:1.5.0",
        'Cmd' => ['--trusted-subnets', '']
      }

      weave = double(:weave, config: weave_config)
      expect(subject.config_changed?(weave, node)).to be_truthy
    end

    it 'returns true if trusted-subnets is not same' do
      node = Node.new(
        'grid' => {
          'trusted_subnets' => ['10.1.2.0/16']
        }
      )
      weave_config = {
        'Image' => valid_image,
        'Cmd' => ['--trusted-subnets', '']
      }

      weave = double(:weave, config: weave_config)
      expect(subject.config_changed?(weave, node)).to be_truthy
    end

    it 'returns false if connection limit is same' do
      node = Node.new(
        'grid' => {
          'trusted_subnets' => []
        }
      )
      weave_config = {
        'Image' => valid_image,
        'Cmd' => ['--trusted-subnets', '', '--conn-limit', '0']
      }
      weave = double(:weave, config: weave_config)
      expect(subject.config_changed?(weave, node)).to be_falsey
    end

    it 'returns true if connection limit is not used' do
      node = Node.new(
        'grid' => {
          'trusted_subnets' => []
        }
      )
      weave_config = {
        'Image' => valid_image,
        'Cmd' => ['--trusted-subnets', '']
      }
      weave = double(:weave, config: weave_config)
      expect(subject.config_changed?(weave, node)).to be_truthy
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
      opts = {
        'Domainname' => 'foo.bar.kontena.io'
      }
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

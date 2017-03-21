
describe Kontena::Launchers::IpamPlugin do

  let(:subject) { described_class.new(false) }
  let(:container) { spy(:container) }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#running?' do
    it 'returns false when ipam container not existing' do
      expect(Docker::Container).to receive(:get).and_return(nil)

      expect(subject.running?).to be_falsey
    end

    it 'returns false when ipam container not running' do
      expect(container).to receive(:running?).and_return(false)
      expect(Docker::Container).to receive(:get).and_return(container)

      expect(subject.running?).to be_falsey
    end

    it 'returns false when ipam container running but api not ready' do
      expect(container).to receive(:running?).and_return(true)
      expect(subject.wrapped_object).to receive(:api_ready?).and_return(false)
      expect(Docker::Container).to receive(:get).and_return(container)

      expect(subject.running?).to be_falsey
    end

    it 'returns true when ipam container and api running' do
      expect(container).to receive(:running?).and_return(true)
      expect(subject.wrapped_object).to receive(:api_ready?).and_return(true)
      expect(Docker::Container).to receive(:get).and_return(container)

      expect(subject.running?).to be_truthy
    end
  end

  describe '#create_container' do

    before do
      allow(subject.wrapped_object).to receive(:image_exists?).and_return(true)
    end

    it 'returns if ipam already running' do
      container = double
      allow(Docker::Container).to receive(:get).and_return(container)
      allow(container).to receive(:running?).and_return(true)
      allow(container).to receive(:info).and_return({'Config' => {'Image' => 'kontena/docker-ipam-plugin:latest'}})

      subject.create_container('kontena/docker-ipam-plugin:latest', nil)

      expect(subject.instance_variable_get(:@running)).to eq(true)
    end

    it 'starts if ipam already exists but not running' do
      container = double
      allow(Docker::Container).to receive(:get).and_return(container)
      allow(container).to receive(:running?).and_return(false)
      allow(container).to receive(:info).and_return({'Config' => {'Image' => 'kontena/docker-ipam-plugin:latest'}})
      expect(container).to receive(:start)

      subject.create_container('kontena/docker-ipam-plugin:latest', nil)

      expect(subject.instance_variable_get(:@running)).to eq(true)
    end

    it 'deletes and recreates the container' do
      container = double
      node = Node.new(
        'node_number' => 1,
        'grid' => {
          'supernet' => '10.80.0.0/12',
        }
      )
      allow(Docker::Container).to receive(:get).and_return(container)
      allow(container).to receive(:info).and_return({'Config' => {'Image' => 'foobar'}})
      expect(container).to receive(:delete)

      ipam_container = double
      expect(Docker::Container).to receive(:create).with(hash_including(
        'name' => 'kontena-ipam-plugin',
        'Image' => 'kontena/docker-ipam-plugin:latest',
        "Volumes" => {"/run/docker/plugins"=>{}, "/var/run/docker.sock"=>{}},
        "StopSignal"=>"SIGTTIN",
        "Cmd"=>["bundle", "exec", "thin", "-a", "127.0.0.1", "-p", "2275", "-e", "production", "start"],
        'Env' => [
          'NODE_ID=1',
          "LOG_LEVEL=1",
          'ETCD_ENDPOINT=http://127.0.0.1:2379',
          'KONTENA_IPAM_SUPERNET=10.80.0.0/12',
        ],
        'HostConfig' => {
          'NetworkMode' => 'host',
          'RestartPolicy' => {'Name' => 'always'},
          'Binds' => ['/run/docker/plugins/:/run/docker/plugins/', '/var/run/docker.sock:/var/run/docker.sock']
        })).and_return(ipam_container)
      expect(ipam_container).to receive(:start)
      allow(ipam_container).to receive(:id).and_return('12345')

      subject.create_container('kontena/docker-ipam-plugin:latest', node)
    end

    it 'creates new container' do
      container = double
      node = Node.new(
        'node_number' => 1,
        'grid' => {
          'supernet' => '10.80.0.0/12',
        }
      )
      allow(Docker::Container).to receive(:get).and_return(nil)
      ipam_container = double
      expect(Docker::Container).to receive(:create).with(hash_including(
        'name' => 'kontena-ipam-plugin',
        'Image' => 'kontena/docker-ipam-plugin:latest',
        "Volumes" => {"/run/docker/plugins"=>{}, "/var/run/docker.sock"=>{}},
        "StopSignal"=>"SIGTTIN",
        "Cmd"=>["bundle", "exec", "thin", "-a", "127.0.0.1", "-p", "2275", "-e", "production", "start"],
        'Env' => [
          'NODE_ID=1',
          "LOG_LEVEL=1",
          'ETCD_ENDPOINT=http://127.0.0.1:2379',
          'KONTENA_IPAM_SUPERNET=10.80.0.0/12',
        ],
        'HostConfig' => {
          'NetworkMode' => 'host',
          'RestartPolicy' => {'Name' => 'always'},
          'Binds' => ['/run/docker/plugins/:/run/docker/plugins/', '/var/run/docker.sock:/var/run/docker.sock']
        })).and_return(ipam_container)
      expect(ipam_container).to receive(:start)
      allow(ipam_container).to receive(:id).and_return('12345')
      subject.create_container('kontena/docker-ipam-plugin:latest', node)
    end
  end
end

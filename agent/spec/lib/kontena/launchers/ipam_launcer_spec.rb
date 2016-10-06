require_relative '../../../spec_helper'

describe Kontena::Launchers::IpamPlugin do

  let(:subject) { described_class.new(false) }
  let(:container) { spy(:container) }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

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
      allow(Docker::Container).to receive(:get).and_return(container)
      allow(container).to receive(:info).and_return({'Config' => {'Image' => 'foobar'}})
      expect(container).to receive(:delete)

      ipam_container = double
      expect(Docker::Container).to receive(:create).with(hash_including(
        'name' => 'kontena-ipam-plugin',
        'Image' => 'kontena/docker-ipam-plugin:latest',
        "Volumes" => {"/run/docker/plugins"=>{}, "/var/run/docker.sock"=>{}},
        'Env' => ['NODE_ID=1'],
        'HostConfig' => {
          'NetworkMode' => 'host',
          'RestartPolicy' => {'Name' => 'always'},
          'Binds' => ['/run/docker/plugins/:/run/docker/plugins/', '/var/run/docker.sock:/var/run/docker.sock']
        })).and_return(ipam_container)
      expect(ipam_container).to receive(:start)
      allow(ipam_container).to receive(:id).and_return('12345')

      subject.create_container('kontena/docker-ipam-plugin:latest', {'node_number' => '1'})
    end

    it 'creates new container' do
      container = double
      allow(Docker::Container).to receive(:get).and_return(nil)
      ipam_container = double
      expect(Docker::Container).to receive(:create).with(hash_including(
        'name' => 'kontena-ipam-plugin',
        'Image' => 'kontena/docker-ipam-plugin:latest',
        "Volumes" => {"/run/docker/plugins"=>{}, "/var/run/docker.sock"=>{}},
        'Env' => ['NODE_ID=1'],
        'HostConfig' => {
          'NetworkMode' => 'host',
          'RestartPolicy' => {'Name' => 'always'},
          'Binds' => ['/run/docker/plugins/:/run/docker/plugins/', '/var/run/docker.sock:/var/run/docker.sock']
        })).and_return(ipam_container)
      expect(ipam_container).to receive(:start)
      allow(ipam_container).to receive(:id).and_return('12345')
      subject.create_container('kontena/docker-ipam-plugin:latest', {'node_number' => '1'})
    end

  end

end

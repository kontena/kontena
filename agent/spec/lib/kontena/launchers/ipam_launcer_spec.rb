require_relative '../../../spec_helper'

describe Kontena::Launchers::IpamPlugin do

  let(:subject) { described_class.new(false) }
  let(:container) { spy(:container) }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#initialize' do
    it 'calls #start by default' do
      expect_any_instance_of(described_class).to receive(:start)
      subject = described_class.new
      sleep 0.01
    end
  end

  describe '#start' do
    it 'pulls image' do
      expect(subject.wrapped_object).to receive(:pull_image)
      expect(subject.wrapped_object).to receive(:create_container)
      subject.start
    end
  end

  describe '#create_container' do
    it 'returns if ipam already running' do
      container = double
      allow(Docker::Container).to receive(:get).and_return(container)
      allow(container).to receive(:running?).and_return(true)
      allow(container).to receive(:info).and_return({'Config' => {'Image' => 'kontena/docker-ipam-plugin:latest'}})

      subject.create_container('kontena/docker-ipam-plugin:latest')

      expect(subject.instance_variable_get(:@running)).to eq(true)
    end

    it 'starts if ipam already exists but not running' do
      container = double
      allow(Docker::Container).to receive(:get).and_return(container)
      allow(container).to receive(:running?).and_return(false)
      allow(container).to receive(:info).and_return({'Config' => {'Image' => 'kontena/docker-ipam-plugin:latest'}})
      expect(container).to receive(:start)

      subject.create_container('kontena/docker-ipam-plugin:latest')

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
        "Volumes" => {"/run/docker/plugins"=>{}},
        'HostConfig' => {
          'NetworkMode' => 'host',
          'RestartPolicy' => {'Name' => 'always'},
          'Binds' => ['/run/docker/plugins/:/run/docker/plugins/']
        })).and_return(ipam_container)
      expect(ipam_container).to receive(:start)
      allow(ipam_container).to receive(:id).and_return('12345')

      subject.create_container('kontena/docker-ipam-plugin:latest')
    end

    it 'creates new container' do
      container = double
      allow(Docker::Container).to receive(:get).and_return(nil)
      ipam_container = double
      expect(Docker::Container).to receive(:create).with(hash_including(
        'name' => 'kontena-ipam-plugin',
        'Image' => 'kontena/docker-ipam-plugin:latest',
        "Volumes" => {"/run/docker/plugins"=>{}},
        'HostConfig' => {
          'NetworkMode' => 'host',
          'RestartPolicy' => {'Name' => 'always'},
          'Binds' => ['/run/docker/plugins/:/run/docker/plugins/']
        })).and_return(ipam_container)
      expect(ipam_container).to receive(:start)
      allow(ipam_container).to receive(:id).and_return('12345')
      subject.create_container('kontena/docker-ipam-plugin:latest')
    end

  end

end

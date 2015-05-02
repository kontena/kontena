require_relative '../../spec_helper'

describe Docker::ContainerStarter do

  let(:node) { HostNode.create!(node_id: SecureRandom.uuid) }
  let(:grid_service) { GridService.create!(name: 'redis', image_name: 'redis:2.8') }
  let(:container) { Container.create!(name: 'redis-1', grid_service: grid_service, host_node: node, image: 'redis:2.8') }
  let(:subject) { described_class.new(container) }
  let(:client) { spy(:client) }

  before(:each) do
    allow(subject).to receive(:client).and_return(client)
  end

  describe '#start_container' do
    it 'sends start request to agent' do
      opts = {'Image' => container.image, 'PortBindings' => {}, 'RestartPolicy' => {'Name' => 'always', 'MaximumRetryCount' => 10}}
      expect(client).to receive(:request).with('/containers/start', container.container_id, opts)
      subject.start_container
    end

    it 'sends volume request to agent if service is stateful' do
      opts = {'Image' => container.image, 'PortBindings' => {}, 'VolumesFrom' => 'volume-1', 'RestartPolicy' => {'Name' => 'always', 'MaximumRetryCount' => 10}}
      allow(grid_service).to receive(:stateful?).and_return(true)
      expect(subject).to receive(:ensure_volume_container).and_return(double(:container, container_id: 'volume-1'))
      expect(client).to receive(:request).with('/containers/start', container.container_id, opts)
      subject.start_container
    end
  end

  describe '#build_volumes' do
    it 'returns correct volumes hash' do
      grid_service.volumes = ['/foo/bar', '/var/run/docker.sock:/var/run/docker.sock']
      expect(subject.build_volumes).to eq({'/foo/bar' => {}})
    end
  end

  describe '#build_bind_volumes' do
    it 'returns correct volume bind array' do
      grid_service.volumes = ['/foo/bar', '/var/run/docker.sock:/var/run/docker.sock']
      expect(subject.build_bind_volumes).to eq(['/var/run/docker.sock:/var/run/docker.sock'])
    end
  end
end
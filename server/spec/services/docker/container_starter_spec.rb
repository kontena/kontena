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
      expect(client).to receive(:request).with('/containers/start', container.container_id)
      subject.start_container
    end
  end
end

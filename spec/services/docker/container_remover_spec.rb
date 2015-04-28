require_relative '../../spec_helper'

describe Docker::ContainerRemover do

  let(:node) { double(:host_node) }
  let(:container) { double(:container, container_id: 'foo-123', running?: false, host_node: node) }
  let(:subject) { described_class.new(container) }
  let(:client) { spy(:client) }

  before(:each) do
    allow(subject).to receive(:client).and_return(client)
  end

  describe '#remove_container' do
    it 'sends remove request to agent' do
      expect(client).to receive(:request).with('/containers/delete', container.container_id, {v: true, force: true})
      expect(container).to receive(:destroy)
      subject.remove_container
    end

    it 'stops container if it is running' do
      allow(container).to receive(:running?).and_return(true)
      expect(client).to receive(:request).with('/containers/stop', container.container_id, {})
      expect(client).to receive(:request).with('/containers/delete', container.container_id, {v: true, force: true})
      expect(container).to receive(:destroy)
      subject.remove_container
    end
  end

end
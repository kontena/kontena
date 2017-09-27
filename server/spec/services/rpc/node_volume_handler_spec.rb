require_relative '../../spec_helper'

describe Rpc::NodeVolumeHandler do
  let(:grid) { Grid.create! }
  let(:subject) { described_class.new(grid) }
  let(:node) { grid.create_node!('test-node', node_id: 'abc') }

  describe '#list' do

    it 'fails if host node does not exist' do
      expect{subject.list('foo')}.to raise_error 'Node not found'
    end

    it 'returns hash with volume instances' do
      volume = grid.volumes.create!(driver: 'local', scope: 'instance', name: 'foo')
      volume_instance = volume.volume_instances.create!(host_node: node, name: 'svc.foo-1')
      list = subject.list(node.node_id)
      expect(list[:volumes][0]).to include(
        name: 'svc.foo-1',
        driver: 'local',
        driver_opts: {},
        volume_id: volume.id.to_s,
        volume_instance_id: volume_instance.id.to_s
      )
    end

    it 'does not return volumes from other node' do
      other_node = grid.create_node!('other-node', node_id: 'def')
      volume = grid.volumes.create!(driver: 'local', scope: 'instance', name: 'foo')
      volume.volume_instances.create!(host_node: node, name: 'svc.foo-1')
      list = subject.list(other_node.node_id)
      expect(list[:volumes]).to eq([])
    end
  end

  describe '#set_state' do
    let(:volume) {
      grid.volumes.create!(driver: 'local', scope: 'instance', name: 'foo')
    }

    let(:data) do
      {
        'name' => 'svc.foo-1',
        'volume_id' => volume.id.to_s,
        'volume_instance_id' => '4567890'
      }
    end

    it 'saves volume instance state to volume' do
      expect {
        subject.set_state(node.node_id, data)
      }.to change {volume.volume_instances.count}.by 1
    end

    it 'does not save volume instance if volume not found' do
      data['volume_id'] = 'foo'
      expect {
        expect{subject.set_state(node.node_id, data)}.to raise_error 'Could not find volume with id: foo'
      }.not_to change {VolumeInstance.count}
    end

    it 'does not save volume instance if already exists' do
      volume_instance = volume.volume_instances.create!(host_node: node, name: 'svc.foo-1')
      data['volume_instance_id'] = volume_instance.id.to_s
      expect {
        subject.set_state(node.node_id, data)
      }.not_to change {VolumeInstance.count}
    end
  end


end

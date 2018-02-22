require_relative '../spec_helper'

describe VolumeInstance do
  it { should be_timestamped_document }
  it { should have_fields(:name) }
  it { should belong_to(:host_node)}
  it { should belong_to(:volume)}

  let(:grid) do
    Grid.create(name: 'test-grid')
  end

  let(:volume) do
    grid.volumes.create!(name: 'vol', driver: 'local', scope: 'instance')
  end

  let(:node) do
    grid.create_node!('node-1', node_id: 'abc')
  end

  it 'deletes volume instances when node is terminated' do
    VolumeInstance.create!(name: 'svc-vol-1', volume: volume, host_node: node)
    expect {
      node.destroy
    }.to change{ VolumeInstance.count }.by (-1)
  end
end

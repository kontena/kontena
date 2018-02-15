require_relative '../../../db/migrations/28_host_node_indexes'

describe HostNodeIndexes do
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:node1) {
    HostNode.create!(grid: grid, node_id: SecureRandom.uuid,
      name: 'test-1', node_number: 1,
      connected: true
    )
  }
  let(:node2) {
    node = HostNode.create!(grid: grid, node_id: SecureRandom.uuid,
      name: 'test-2', node_number: 2,
      connected: true
    )
    node.unset(:name)
    node
  }
  let(:node3) {
    node = HostNode.create!(grid: grid, node_id: SecureRandom.uuid,
      name: 'test-0', node_number: 3,
      connected: true
    )
    node.unset(:name, :node_number)
    node
  }

  before do
    HostNode.collection.indexes.drop_all
    node1
    node2
    node3
  end

  it 'initializes missing node names to allow creating the unique index' do
    expect{described_class.up}.to_not raise_error # Mongo::Error::OperationFailure: exception: E11000 duplicate key error index: kontena_test.host_nodes.$grid_id_1_name_1 dup key: { : ObjectId('5992e4d3de3578212142bcef'), : null } (11000)

    expect(node1.reload.name).to eq 'test-1'
    expect(node2.reload.name).to eq 'node-2'
    expect(node3.reload.name).to eq 'node-3'
  end
end

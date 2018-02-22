require_relative '../../spec_helper'

describe Volumes::Delete do

  let! :grid do
    grid = Grid.create!(name: 'terminal-a')
  end

  let! :volume do
    Volume.create!(
      grid: grid,
      name: 'vol',
      driver: 'some-driver',
      scope: 'grid'
    )
  end

  let! :node1 do
    grid.create_node!('foo', node_id: 'aaa', connected: true)
  end

  let! :node2 do
    grid.create_node!('bar', node_id: 'bbb', connected: true)
  end

  describe '#run' do
    it 'deletes a volume that\'s not in use' do
      expect {
        outcome = described_class.new(volume: volume).run
        expect(outcome.success?).to be_truthy
      }.to change{Volume.count}. by -1
    end

    it 'deletes a volume that\'s not in use and notifies nodes where instances are' do
      rpc_client = double(:rpc_client)
      allow(RpcClient).to receive(:new).and_return(rpc_client)
      expect(rpc_client).to receive(:notify).twice
      volume.volume_instances.create!(name: 'foo1', host_node: node1)
      volume.volume_instances.create!(name: 'foo2', host_node: node2)
      expect {
        outcome = described_class.new(volume: volume).run
        expect(outcome.success?).to be_truthy
      }.to change{Volume.count}. by -1
    end

    it 'does not delete a volume that\'s in use' do
      GridServices::Create.run(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false,
          volumes: [
            "#{volume.name}:/data:ro"
          ]
      )
      expect {
        outcome = described_class.new(volume: volume).run
        expect(outcome.success?).to be_falsey
      }.not_to change{Volume.count}
    end

  end

end

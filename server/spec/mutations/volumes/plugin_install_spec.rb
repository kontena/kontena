require_relative '../../spec_helper'

describe Volumes::PluginInstall do

  let! :grid do
    grid = Grid.create!(name: 'terminal-a')
  end

  let! :node_a do
    HostNode.create!(name: 'node-a', grid: grid, node_id: 'AA', connected: true)
  end

  let! :node_b do
    HostNode.create!(name: 'node-b', grid: grid, node_id: 'BB', connected: true)
  end

  let! :rpc_client do
    double(RpcClient)
  end

  describe '#execute' do
    it 'installs plugin on all nodes' do
      mutation = described_class.new(grid: grid, name: 'rexray/s3fs:latest')

      expect(RpcClient).to receive(:new).twice.and_return(rpc_client)
      expect(rpc_client).to receive(:request).with('/plugins/install', 'rexray/s3fs:latest', nil, nil).twice.and_return({})

      outcome = mutation.run
      expect(outcome.success?).to be_truthy
    end

    it 'installs plugin on connected nodes' do
      node_b.set({:connected => false})
      mutation = described_class.new(grid: grid, name: 'rexray/s3fs:latest')

      expect(RpcClient).to receive(:new).once.with('AA').and_return(rpc_client)
      expect(rpc_client).to receive(:request).with('/plugins/install', 'rexray/s3fs:latest', nil, nil).and_return({})

      outcome = mutation.run
      expect(outcome.success?).to be_truthy
    end

    it 'installs plugin on all nodes' do
      node_b.set({:labels => ['provider=aws']})
      mutation = described_class.new(grid: grid, name: 'rexray/s3fs:latest', label: 'provider=aws')
      expect(RpcClient).to receive(:new).once.with('BB').and_return(rpc_client)
      expect(rpc_client).to receive(:request).with('/plugins/install', 'rexray/s3fs:latest', nil, nil).and_return({})

      outcome = mutation.run

      expect(outcome.success?).to be_truthy
    end

  end

end
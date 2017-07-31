require 'kontena/cli/nodes/create_command'

describe Kontena::Cli::Nodes::CreateCommand do
  include ClientHelpers
  include OutputHelpers

  it 'POSTs the node' do
    expect(client).to receive(:post).with('grids/test-grid/nodes', {name: 'node-4', labels: []})

    subject.run(['node-4'])
  end

  it 'POSTs the node with labels' do
    expect(client).to receive(:post).with('grids/test-grid/nodes', {name: 'node-4', labels: ['test=4']})

    subject.run(['-l', 'test=4', 'node-4'])
  end

  it 'POSTs with given token' do
    expect(client).to receive(:post).with('grids/test-grid/nodes', {name: 'node-4', labels: [], token: 'asdf'})

    subject.run(['--token=asdf', 'node-4'])
  end
end

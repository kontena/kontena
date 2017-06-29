require 'kontena/cli/nodes/update_command'

describe Kontena::Cli::Nodes::UpdateCommand do
  include ClientHelpers
  include OutputHelpers

  it 'PUTs with empty parameters by default' do
    expect(client).to receive(:put).with('nodes/test-grid/test-node', {})

    subject.run(['test-node'])
  end

  it 'PUTs with labels' do
    expect(client).to receive(:put).with('nodes/test-grid/test-node', {labels: ['test1=yes', 'test2=no']})

    subject.run(['-l', 'test1=yes', '--label=test2=no', 'test-node'])
  end

  it 'PUTs with empty labels' do
    expect(client).to receive(:put).with('nodes/test-grid/test-node', {labels: []})

    subject.run(['--clear-labels', 'test-node'])
  end

  it 'PUTs token' do
    expect(client).to receive(:put).with('nodes/test-grid/test-node/token', {token: 'asdf'})
    expect(client).to receive(:put).with('nodes/test-grid/test-node', {})

    subject.run(['--token=asdf', 'test-node'])
  end

  it 'PUTs to generate token' do
    expect(client).to receive(:put).with('nodes/test-grid/test-node/token', {})
    expect(client).to receive(:put).with('nodes/test-grid/test-node', {})

    subject.run(['--generate-token', 'test-node'])
  end
end

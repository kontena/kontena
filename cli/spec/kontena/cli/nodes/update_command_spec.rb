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

  it 'prompts on token update' do
    expect(subject).to receive(:confirm).with("Updating the node token will require you to reconfigure the kontena-agent before it will be able to reconnect. Are you sure?")
    
    expect(client).to receive(:put).with('nodes/test-grid/test-node/token', {token: 'asdf', reset_connection: true})
    expect(client).to receive(:put).with('nodes/test-grid/test-node', {})

    subject.run(['--force', '--token=asdf', 'test-node'])
  end

  it 'PUTs token with reset_connection' do
    expect(client).to receive(:put).with('nodes/test-grid/test-node/token', {token: 'asdf', reset_connection: true})
    expect(client).to receive(:put).with('nodes/test-grid/test-node', {})

    subject.run(['--force', '--token=asdf', 'test-node'])
  end

  it 'PUTs to generate token with reset_connection' do
    expect(client).to receive(:put).with('nodes/test-grid/test-node/token', {reset_connection: true})
    expect(client).to receive(:put).with('nodes/test-grid/test-node', {})

    subject.run(['--force', '--generate-token', 'test-node'])
  end

  it 'PUTs to generate token without reset_connection' do
    expect(client).to receive(:put).with('nodes/test-grid/test-node/token', {reset_connection: false})
    expect(client).to receive(:put).with('nodes/test-grid/test-node', {})

    subject.run(['--force', '--generate-token', '--no-reset-connection', 'test-node'])
  end
end

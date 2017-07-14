require 'kontena/cli/nodes/reset_command'

describe Kontena::Cli::Nodes::ResetCommand do
  include ClientHelpers
  include OutputHelpers

  it 'prompts on token update' do
    expect(subject).to receive(:confirm).with("Resetting the node token will disconnect the agent (unless using --no-reset-connection), and require you to reconfigure the kontena-agent using the new `kontena node env` values before it will be able to reconnect. Are you sure?")

    expect(client).to receive(:put).with('nodes/test-grid/test-node/token', {reset_connection: true})

    subject.run(['test-node'])
  end

  it 'PUTs token with reset_connection' do
    expect(client).to receive(:put).with('nodes/test-grid/test-node/token', {token: 'asdf', reset_connection: true})

    subject.run(['--force', '--token=asdf', 'test-node'])
  end

  it 'PUTs to generate token with reset_connection' do
    expect(client).to receive(:put).with('nodes/test-grid/test-node/token', {reset_connection: true})

    subject.run(['--force', 'test-node'])
  end

  it 'PUTs to generate token without reset_connection' do
    expect(client).to receive(:put).with('nodes/test-grid/test-node/token', {reset_connection: false})

    subject.run(['--force', '--no-reset-connection', 'test-node'])
  end
end

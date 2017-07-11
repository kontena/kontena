require 'kontena/cli/nodes/update_command'

describe Kontena::Cli::Nodes::UpdateCommand do
  include ClientHelpers
  include OutputHelpers

  it 'PUTs with labels' do
    expect(client).to receive(:put).with('nodes/test-grid/test-node', {labels: ['test1=yes', 'test2=no']})

    subject.run(['-l', 'test1=yes', '--label=test2=no', 'test-node'])
  end

  it 'PUTs with empty labels' do
    expect(client).to receive(:put).with('nodes/test-grid/test-node', {labels: []})

    subject.run(['test-node'])
  end
end

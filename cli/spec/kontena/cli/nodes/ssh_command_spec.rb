require 'kontena/cli/nodes/ssh_command'

describe Kontena::Cli::Nodes::SshCommand do
  include ClientHelpers

  let :node do
    {
      'labels' => [],
      'public_ip' => '192.0.2.10',
      'private_ip' => '10.0.8.10',
      'overlay_ip' => '10.81.0.1',
    }
  end

  before do
    allow(client).to receive(:get).with('nodes/test-grid/test-node').and_return(node)
  end

  describe '--any flag' do
    context 'used together with a node name' do
      it "fails and outputs an error message" do
        expect(subject).to_not receive(:exec)
        expect{subject.run(['--any', 'ls', '-l'])}.to exit_with_error.and output(/Cannot combine --any with a node name/).to_stderr
      end
    end

    context 'used when there are no connected nodes' do
      before do
        expect(subject.client).to receive(:get).with("grids/test-grid/nodes").and_return('nodes' => [ { 'connected' => false } ])
      end

      it "fails and outputs an error message" do
        expect(subject).to_not receive(:exec)
        expect{subject.run(['--any'])}.to exit_with_error.and output(/no online nodes/).to_stderr
      end
    end
  end

  it "uses the public IP by default" do
    expect(subject).to receive(:exec).with('ssh', 'core@192.0.2.10')
    subject.run ['test-node']
  end

  it "uses the private IP" do
    expect(subject).to receive(:exec).with('ssh', 'core@10.0.8.10')
    subject.run ['--private-ip', 'test-node']
  end

  it "uses the overlay IP" do
    expect(subject).to receive(:exec).with('ssh', 'core@10.81.0.1')
    subject.run ['--internal-ip', 'test-node']
  end

  it "passes through the command to SSH" do
    expect(subject).to receive(:exec).with('ssh', 'core@192.0.2.10', 'ls', '-l')
    subject.run ['test-node', 'ls', '-l']
  end

  it "passes through arguments to SSH" do
    expect(subject).to receive(:exec).with('ssh', 'core@192.0.2.10', '-F', 'ssh/config' 'ls', '-l')
    subject.run ['test-node', '-F', 'ssh/config' 'ls', '-l']
  end
end

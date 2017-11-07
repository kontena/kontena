require 'kontena/cli/nodes/remove_command'

describe Kontena::Cli::Nodes::RemoveCommand do
  include ClientHelpers
  include OutputHelpers

  context 'for an offline node without a node token' do
    let :node do
      {
        "id" => 'test-grid/node-1',
        "name" => 'node-1',
        "has_token" => false,
        "connected" => false,
      }
    end

    before do
      expect(client).to receive(:get).with('nodes/test-grid/node-1').and_return(node)
    end

    it 'removes the node' do
      expect(subject).to receive(:confirm_command).with('node-1')
      expect(client).to receive(:delete).with('nodes/test-grid/node-1')

      subject.run(['node-1'])
    end

    it 'removes the node with --force' do
      expect(client).to receive(:delete).with('nodes/test-grid/node-1')

      subject.run(['--force', 'node-1'])
    end
  end

  context 'for an online node without a node token' do
    let :node do
      {
        "id" => 'test-grid/node-1',
        "name" => 'node-1',
        "has_token" => false,
        "connected" => true,
      }
    end

    before do
      expect(client).to receive(:get).with('nodes/test-grid/node-1').and_return(node)
    end

    it 'does not remove the node' do
      expect(client).not_to receive(:delete)

      expect{subject.run(['node-1'])}.to exit_with_error.and output(" [error] Node node-1 is still online. You must terminate the node before removing it.\n").to_stderr
    end
  end

  context 'for an online node with a node token' do
    let :node do
      {
        "id" => 'test-grid/node-1',
        "name" => 'node-1',
        "has_token" => true,
        "connected" => true,
      }
    end

    before do
      expect(client).to receive(:get).with('nodes/test-grid/node-1').and_return(node)
    end

    it 'removes the node' do
      expect(client).to receive(:delete).with('nodes/test-grid/node-1')

      expect{subject.run(['--force', 'node-1'])}.to output(/\[warn\] Node node-1 is still connected using a node token, but will be force-disconnected/).to_stderr
    end
  end
end

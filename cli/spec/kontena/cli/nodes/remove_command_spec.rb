require 'kontena/cli/nodes/remove_command'

describe Kontena::Cli::Nodes::RemoveCommand do
  include ClientHelpers
  include OutputHelpers

  context 'for an offline node' do
    let :node do
      {
        "id" => 'test-grid/node-1',
        "name" => 'node-1',
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

  context 'for an online node' do
    let :node do
      {
        "id" => 'test-grid/node-1',
        "name" => 'node-1',
        "connected" => true,
      }
    end

    before do
      expect(client).to receive(:get).with('nodes/test-grid/node-1').and_return(node)
    end

    it 'does not remove the node' do
      expect(client).not_to receive(:delete)

      expect{subject.run(['node-1'])}.to output(" [error] Node node-1 is still online. You must terminate the node before removing it.\n").to_stderr
    end
  end
end

require 'kontena/cli/nodes/label_command'
require 'kontena/cli/nodes/labels/remove_command'

describe Kontena::Cli::Nodes::Labels::RemoveCommand do
  include ClientHelpers
  include OutputHelpers

  before do
    allow(client).to receive(:get).with('nodes/test-grid/node').and_return(node)
  end

  context "for a node without any labels" do
    let :node do
      {
        "id" => 'test-grid/node',
        "name" => "node",
        "labels" => [],
      }
    end

    context "when removing an unknown label" do
      context "with --force" do
        it 'does nothing' do
          expect(client).not_to receive(:put)
          expect{subject.run(['--force', 'node', 'test=yes'])}.not_to exit_with_error
        end
      end

      context "without --force" do
        it "exits with error" do
          expect(client).not_to receive(:put)
          expect{subject.run(['node', 'test=yes'])}.to exit_with_error.and output(/not found/).to_stderr
        end
      end
    end
  end

  context "for a node with labels" do
    let :node do
      {
        "id" => 'test-grid/node',
        "name" => "node",
        "labels" => [
          'test=yes',
          'test=no',
        ],
      }
    end

    it "removes labels" do
      expect(client).to receive(:put).with('nodes/test-grid/node', {
          labels: ['test=no'],
      })

      subject.run(['node', 'test=yes'])
    end

    it "removes all labels" do
      expect(client).to receive(:put).with('nodes/test-grid/node', {
          labels: [],
      })

      subject.run(['node', 'test=yes', 'test=no'])
    end

    context "when removing an unknown label" do
      context "without --force" do
        it "exits with error" do
          expect{subject.run(['node', 'test=yes', 'test=no', 'test=maybe'])}.to exit_with_error.and output(/Label test=maybe not found/).to_stderr
        end

        it "exits with plural error" do
          expect{subject.run(['node', 'test=yes', 'test=no', 'test=maybe', 'test=almost'])}.to exit_with_error.and output(/Labels test=maybe, test=almost not found/).to_stderr
        end
      end
      context "with --force" do
        it 'ignores any labels that were not found with --force' do
          expect(client).to receive(:put).with('nodes/test-grid/node', {
              labels: ['test=yes'],
          })

          expect{subject.run(['--force', 'node', 'test=no', 'test=maybe', 'test=almost'])}.not_to exit_with_error
        end
      end
    end
  end
end

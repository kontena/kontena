require "kontena/cli/stacks/remove_command"

describe Kontena::Cli::Stacks::RemoveCommand do

  include ClientHelpers

  describe '#execute' do
    it 'sends remove command to master' do
      allow(subject).to receive(:wait_stack_removal)
      expect(client).to receive(:delete).with('stacks/test-grid/test-stack')
      subject.run(['--force', 'test-stack'])
    end

    it 'waits until service is removed' do
      allow(client).to receive(:delete).with('stacks/test-grid/test-stack')
      expect(client).to receive(:get).with('stacks/test-grid/test-stack')
        .and_raise(Kontena::Errors::StandardError.new(404, 'Not Found'))
      subject.run(['--force', 'test-stack'])
    end

    it 'raises exception on server error' do
      expect(client).to receive(:delete).with('stacks/test-grid/test-stack')
      expect(client).to receive(:get).with('stacks/test-grid/test-stack')
        .and_raise(Kontena::Errors::StandardError.new(500, 'internal error'))
      expect{
        subject.run(['--force', 'test-stack'])
      }.to exit_with_error
    end
  end
end

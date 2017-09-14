require "kontena/cli/stacks/remove_command"

describe Kontena::Cli::Stacks::RemoveCommand do

  include ClientHelpers

  describe '#execute' do
    it 'sends remove command to master' do
      allow(subject).to receive(:fetch_stack).and_return({})
      allow(subject).to receive(:wait_stack_removal)
      expect(client).to receive(:delete).with('stacks/test-grid/test-stack')
      subject.run(['--force', 'test-stack'])
    end

    it 'waits until service is removed' do
      allow(subject).to receive(:fetch_stack).and_return({})
      allow(client).to receive(:delete).with('stacks/test-grid/test-stack')
      expect(client).to receive(:get).with('stacks/test-grid/test-stack')
        .and_raise(Kontena::Errors::StandardError.new(404, 'Not Found'))
      subject.run(['--force', 'test-stack'])
    end

    it 'raises exception on server error' do
      allow(subject).to receive(:fetch_stack).and_return({})
      expect(client).to receive(:delete).with('stacks/test-grid/test-stack')
      expect(client).to receive(:get).with('stacks/test-grid/test-stack')
        .and_raise(Kontena::Errors::StandardError.new(500, 'internal error'))
      expect{
        subject.run(['--force', 'test-stack'])
      }.to exit_with_error
    end

    describe 'with stack dependencies' do
      context 'when stack has a parent' do
        let(:stack_response_with_parent) do
          { 'parent' => { 'name' => 'foofoo' } }
        end

        it 'warns' do
          expect(client).to receive(:get).with('stacks/test-grid/test-stack').and_return(
            stack_response_with_parent
          )
          expect(subject).to receive(:confirm_command).and_raise "foo"
          expect{subject.run(['test-stack'])}.to exit_with_error.and output(/depends on/).to_stdout
        end
      end

      context 'when stack has children' do
        let(:stack_response_with_children) do
          { 'children' => [ { 'name' => 'foofoo' }, { 'name' => 'foobar' } ] }
        end

        it 'removes the children' do
          allow(subject).to receive(:wait_stack_removal)

          expect(client).to receive(:get).with('stacks/test-grid/test-stack').and_return(
            stack_response_with_children
          )

          expect(Kontena).to receive(:run!).with(['stack', 'remove', '--force', 'foofoo'])
          expect(Kontena).to receive(:run!).with(['stack', 'remove', '--force', 'foobar'])

          expect(subject).to receive(:remove_stack).with('test-stack')
          expect{subject.run(['--force', 'test-stack'])}.not_to exit_with_error
        end
      end
    end
  end
end

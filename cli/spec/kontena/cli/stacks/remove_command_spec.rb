require "kontena/cli/stacks/remove_command"

describe Kontena::Cli::Stacks::RemoveCommand do

  include ClientHelpers

  let(:deployment) { double() }

  describe '#execute' do
    context "with an installed stack" do
      let(:stack) { {

      } }

      before do
        allow(subject).to receive(:fetch_stack).and_return(stack)
      end

      it 'waits for terminate deploy before deleting' do
        expect(client).to receive(:post).with('stacks/test-grid/test-stack/terminate', {}).and_return(deployment)
        expect(subject).to receive(:wait_for_deploy_to_finish).with(deployment)
        expect(client).to receive(:delete).with('stacks/test-grid/test-stack')

        subject.run(['--force', 'test-stack'])
      end

      it 'raises exception on server error' do
        expect(client).to receive(:post).with('stacks/test-grid/test-stack/terminate', {}).and_raise(Kontena::Errors::StandardError.new(500, 'internal error'))

        expect{
          subject.run(['--force', 'test-stack'])
        }.to exit_with_error
      end
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

        before(:each) do
          allow(subject).to receive(:terminate_stack)
        end

        it 'removes the children' do
          expect(client).to receive(:get).with('stacks/test-grid/test-stack').and_return(
            stack_response_with_children
          )

          expect(Kontena).to receive(:run!).with(['stack', 'remove', '--force', 'foofoo'])
          expect(Kontena).to receive(:run!).with(['stack', 'remove', '--force', 'foobar'])

          expect(subject).to receive(:remove_stack).with('test-stack')
          expect {
            subject.run(['--force', 'test-stack'])
          }.not_to exit_with_error
        end

        it 'does not remove the children if keep dependencies given' do
          allow(subject).to receive(:confirm_command)
          expect(client).to receive(:get).with('stacks/test-grid/test-stack').and_return(
            stack_response_with_children
          )

          expect(Kontena).not_to receive(:run!).with(['stack', 'remove', '--force', 'foofoo'])
          expect(Kontena).not_to receive(:run!).with(['stack', 'remove', '--force', 'foobar'])

          expect(subject).to receive(:remove_stack).with('test-stack')
          expect {
            expect {
              subject.run(['--keep-dependencies', 'test-stack'])
            }.not_to output(/depends on/).to_stdout
          }.not_to exit_with_error
        end
      end
    end
  end
end

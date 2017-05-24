require_relative "../../../spec_helper"
require 'kontena/cli/vault/write_command'

describe Kontena::Cli::Vault::WriteCommand do

  include RequirementsHelper
  include ClientHelpers

  let(:subject) { described_class.new(File.basename($0)) }

  describe '#execute' do
    context 'without value parameter' do

      let(:stdin) { double(:stdin) }

      before(:each) do
        @old_stdin = $stdin
        $stdin = stdin
      end

      after(:each) { $stdin = @old_stdin }

      context 'no tty' do
        context 'stdin empty' do
          it 'returns an error' do
            expect(stdin).to receive(:tty?).and_return(false)
            expect(stdin).to receive(:eof?).and_return(true)
            expect{subject.run(['mysql_password'])}.to exit_with_error.and output(/Missing/).to_stderr
          end
        end

        context 'stdin has a value' do
          it 'sends create request' do
            expect(stdin).to receive(:tty?).and_return(false)
            expect(stdin).to receive(:eof?).and_return(false)
            expect(stdin).to receive(:read).and_return('secret')
            expect(client).to receive(:post).with('grids/test-grid/secrets', { name: 'mysql_password', value: 'secret'})
            expect{subject.run(['mysql_password'])}.not_to exit_with_error
          end
        end
      end

      context 'with tty' do
        let(:prompt) { double(:prompt) }
        it 'prompts value from STDIN' do
          expect(stdin).to receive(:tty?).and_return(true)
          expect(subject).to receive(:prompt).and_return(prompt)
          expect(prompt).to receive(:mask).and_return('secret')
          expect(client).to receive(:post).with('grids/test-grid/secrets', { name: 'mysql_password', value: 'secret'})
          expect{subject.run(['mysql_password'])}.not_to exit_with_error
        end
      end
    end

    it 'sends create request' do
      expect(client).to receive(:post).with('grids/test-grid/secrets', { name: 'mysql_password', value: 'secret'})
      subject.run(['mysql_password', 'secret'])
    end
  end
end

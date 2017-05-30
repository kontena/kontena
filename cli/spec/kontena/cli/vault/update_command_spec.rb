require_relative "../../../spec_helper"
require 'kontena/cli/vault/update_command'

describe Kontena::Cli::Vault::UpdateCommand do

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

      context 'without tty' do
        before(:each) { allow(stdin).to receive(:tty?).and_return(false) }
        after(:each) { $stdin = @old_stdin }

        context 'nothing in stdin' do
          before(:each) do
            allow(stdin).to receive(:eof?).and_return(true)
          end

          it 'returns error if value not provided' do
            expect{subject.run(['mysql_password'])}.to exit_with_error.and output(/Missing/).to_stderr
          end
        end

        context 'value in stdin' do
          it 'sends update request' do
            expect(stdin).to receive(:eof?).and_return(false)
            expect(stdin).to receive(:read).and_return('secret')
            expect(client).to receive(:put).with('secrets/test-grid/mysql_password', { name: 'mysql_password', value: 'secret', upsert: false})
            expect{subject.run(['mysql_password'])}.not_to exit_with_error
          end
        end
      end

      context 'with tty' do
        before(:each) do
          allow(stdin).to receive(:tty?).and_return(true)
        end

        context 'when value not given' do
          let(:prompt) { double(:prompt) }
          it 'prompts for value' do
            expect(subject).to receive(:prompt).and_return(prompt)
            expect(prompt).to receive(:mask).once.and_return('very-secret')
            expect(client).to receive(:put).with('secrets/test-grid/mysql_password', { name: 'mysql_password', value: 'very-secret', upsert: false})
            expect{subject.run(['mysql_password'])}.not_to exit_with_error
          end
        end
      end
    end

    context 'with value parameter' do
      it 'sends update request' do
        expect(client).to receive(:put).with('secrets/test-grid/mysql_password', { name: 'mysql_password', value: 'secret', upsert: false})
        expect{subject.run(['mysql_password', 'secret'])}.not_to exit_with_error
      end

      context 'when giving --upsert flag' do
        it 'sets upsert true' do
          expect(client).to receive(:put).with('secrets/test-grid/mysql_password', { name: 'mysql_password', value: 'secret', upsert: true})
          subject.run(['-u', 'mysql_password', 'secret'])
        end
      end
    end
  end
end

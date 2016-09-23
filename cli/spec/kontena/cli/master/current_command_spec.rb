require_relative "../../../spec_helper"
require 'kontena/cli/master/current_command'

describe Kontena::Cli::Master::CurrentCommand do
  include ClientHelpers
  
  let(:subject) { described_class.new(File.basename($0)) }

  describe '#execute' do
    it 'puts master name and URL' do
      expect {
        subject.run([])
      }.to output(/alias.*someurl/).to_stdout
    end

    it 'only outputs name if name-flag is set' do
      expect {
        subject.run(['--name'])
      }.to output("alias\n").to_stdout
    end

    it 'does not raise error when logged in' do
      expect {
        subject.run([])
      }.to_not raise_error
    end

    it 'raises error when not logged in' do
      expect(subject.config).to receive(:current_master).and_return(nil)

      expect {
        subject.run([])
      }.to raise_error(ArgumentError)
    end
  end
end

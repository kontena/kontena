require_relative "../../../spec_helper"
require 'kontena/cli/master/use_command'

describe Kontena::Cli::Master::UseCommand do

  include ClientHelpers

  let(:subject) do
    described_class.new(File.basename($0))
  end

  describe '#use' do
    it 'should update current master' do
      expect(subject).to receive(:current_master=).with('some_master')
      subject.run(['some_master'])
    end

    it 'should abort with error message if master is not configured' do
      expect { subject.run(['not_existing']) }.to raise_error(
        SystemExit, /Could not resolve master with name: not_existing/)
    end
  end
end

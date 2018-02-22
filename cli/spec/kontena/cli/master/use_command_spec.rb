require 'kontena/cli/master/use_command'

describe Kontena::Cli::Master::UseCommand do

  include ClientHelpers

  let(:subject) do
    described_class.new(File.basename($0))
  end

  describe '#use' do
    it 'should update current master' do
      expect(subject.config).to receive(:write).and_return(true)
      subject.run(['some_master'])
      expect(subject.config.current_server).to eq 'some_master'
    end

    it 'should abort with error message if master is not configured' do
      expect { subject.run(['not_existing']) }.to exit_with_error.and output(/Could not resolve master by name 'not_existing'/).to_stderr
    end

    it 'should abort with error message if master is not given' do
      expect { subject.run([]) }.to raise_error Clamp::UsageError
    end

    it 'should clear current master when --clear given' do
      expect(subject.config).to receive(:write).and_return(true)
      subject.run(['--clear'])
      expect(subject.config.current_server).to be_nil
    end
  end
end

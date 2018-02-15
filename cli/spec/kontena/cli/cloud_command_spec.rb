require 'kontena/cli/cloud_command'

describe Kontena::Cli::CloudCommand do
  let(:subject) { described_class.new('kontena') }


  describe '#subcommand_missing' do
    it 'suggests plugin install for known cloud plugin commands' do
      expect{subject.run(['platform', 'xyz'])}.to exit_with_error.and output(/has not been installed/).to_stderr
      expect{subject.run(['organization', 'xyz'])}.to exit_with_error.and output(/has not been installed/).to_stderr
      expect{subject.run(['ir', 'xyz'])}.to exit_with_error.and output(/has not been installed/).to_stderr
      expect{subject.run(['region', 'xyz'])}.to exit_with_error.and output(/has not been installed/).to_stderr
      expect{subject.run(['node', 'xyz'])}.to exit_with_error.and output(/has not been installed/).to_stderr
      expect{subject.run(['token', 'xyz'])}.to exit_with_error.and output(/has not been installed/).to_stderr
    end
  end
end

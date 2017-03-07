require "kontena/cli/services/restart_command"

describe Kontena::Cli::Services::RestartCommand do

  include ClientHelpers

  describe '#execute' do
    it 'triggers restart command' do
      expect(subject).to receive(:restart_service)
      subject.run(['service'])
    end
  end
end

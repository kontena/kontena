require "kontena/cli/version_command"

describe Kontena::Cli::VersionCommand do

  include ClientHelpers

  let :http_client do
    double(:http_client)
  end

  describe '#execute' do
    it 'runs without errors' do
      expect(client).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:get).with(path: '/').and_return(double(body: '{"version": "0.1"}'))

      expect { subject.run([]) }.to output("cli: #{Kontena::Cli::VERSION}\nmaster: 0.1 (#{subject.current_master.url})\n").to_stdout
    end
  end
end

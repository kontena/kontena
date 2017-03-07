require "kontena/cli/grids/trusted_subnet_command"
require "kontena/cli/grids/trusted_subnets/list_command"

describe Kontena::Cli::Grids::TrustedSubnets::ListCommand do

  include ClientHelpers

  describe '#execute' do
    it 'requires grid as param' do
      expect {
        subject.run([])
      }.to raise_error(Clamp::UsageError)
    end

    it 'requests grid details from master' do
      expect(client).to receive(:get).with("grids/test-grid").and_return('trusted_subnets' => [
          '192.168.0.1/24',
      ])
      expect{subject.run(['test-grid'])}.to output("192.168.0.1/24\n").to_stdout
    end
  end
end

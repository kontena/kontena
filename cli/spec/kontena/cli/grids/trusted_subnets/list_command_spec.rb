require "kontena/cli/grids/trusted_subnet_command"
require "kontena/cli/grids/trusted_subnets/list_command"

describe Kontena::Cli::Grids::TrustedSubnets::ListCommand do

  include ClientHelpers
  include RequirementsHelper

  expect_to_require_current_master

  describe '#execute' do
    it 'requests grid details from master' do
      expect(client).to receive(:get).with("grids/test-grid").and_return('trusted_subnets' => [
          '192.168.0.1/24',
      ])
      expect{subject.run([])}.to output("192.168.0.1/24\n").to_stdout
    end

    it 'supports the --grid option' do
      allow(subject).to receive(:current_grid).and_call_original
      expect(client).to receive(:get).with("grids/ingrid").and_return('trusted_subnets' => [
          '192.168.0.1/24',
      ])
      expect{subject.run(['--grid', 'ingrid'])}.to output("192.168.0.1/24\n").to_stdout
    end
  end
end

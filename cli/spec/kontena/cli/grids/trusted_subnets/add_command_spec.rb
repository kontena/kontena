require "kontena/cli/grids/trusted_subnet_command"
require "kontena/cli/grids/trusted_subnets/add_command"

describe Kontena::Cli::Grids::TrustedSubnets::AddCommand do

  include ClientHelpers
  include RequirementsHelper

  expect_to_require_current_master

  describe '#execute' do
    it 'requires subnet as param' do
      expect {
        subject.run([])
      }.to raise_error(Clamp::UsageError)
    end

    it 'adds subnet to grid' do
      allow(client).to receive(:get).with("grids/test-grid").and_return(
        'trusted_subnets' => ['192.168.12.0/24']
      )
      expect(client).to receive(:put).with(
        'grids/test-grid', hash_including({trusted_subnets: [
          '192.168.12.0/24', '10.12.0.0/19'
        ]})
      )
      subject.run(['10.12.0.0/19'])
    end

    it 'supports the --grid option' do
      allow(subject).to receive(:current_grid).and_call_original
      allow(client).to receive(:get).with("grids/ingrid").and_return(
        'trusted_subnets' => ['192.168.12.0/24']
      )
      expect(client).to receive(:put).with(
        'grids/ingrid', hash_including({trusted_subnets: [
          '192.168.12.0/24', '10.12.0.0/19'
        ]})
      )
      subject.run(['--grid', 'ingrid', '10.12.0.0/19'])
    end
  end
end

require "kontena/cli/grids/trusted_subnet_command"
require "kontena/cli/grids/trusted_subnets/remove_command"

describe Kontena::Cli::Grids::TrustedSubnets::RemoveCommand do

  include ClientHelpers
  include RequirementsHelper

  expect_to_require_current_master

  describe '#execute' do
    it 'requires subnet as param' do
      expect {
        subject.run([])
      }.to raise_error(Clamp::UsageError)
    end

    it 'removes subnet from grid' do
      allow(client).to receive(:get).with("grids/test-grid").and_return(
        'trusted_subnets' => ['192.168.12.0/24', '192.168.50.0/24']
      )
      expect(client).to receive(:put).with(
        'grids/test-grid', hash_including({trusted_subnets: [
          '192.168.12.0/24'
        ]})
      )
      subject.run(['--force', '192.168.50.0/24'])
    end

    it 'supports the --grid option' do
      allow(subject).to receive(:current_grid).and_call_original
      allow(client).to receive(:get).with("grids/ingrid").and_return(
        'trusted_subnets' => ['192.168.12.0/24', '192.168.50.0/24']
      )
      expect(client).to receive(:put).with(
        'grids/ingrid', hash_including({trusted_subnets: [
          '192.168.12.0/24'
        ]})
      )
      subject.run(['--force', '--grid', 'ingrid', '192.168.50.0/24'])
    end
  end
end

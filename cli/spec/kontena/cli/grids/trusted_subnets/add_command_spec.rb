require "kontena/cli/grids/trusted_subnet_command"
require "kontena/cli/grids/trusted_subnets/add_command"

describe Kontena::Cli::Grids::TrustedSubnets::AddCommand do

  include ClientHelpers

  describe '#execute' do
    it 'requires grid as param' do
      expect {
        subject.run([])
      }.to raise_error(Clamp::UsageError)
    end

    it 'adds subnet to grid' do
      allow(client).to receive(:get).with("grids/my-grid").and_return(
        'trusted_subnets' => ['192.168.12.0/24']
      )
      expect(client).to receive(:put).with(
        'grids/my-grid', hash_including({trusted_subnets: [
          '192.168.12.0/24', '10.12.0.0/19'
        ]})
      )
      subject.run(['my-grid', '10.12.0.0/19'])
    end
  end
end

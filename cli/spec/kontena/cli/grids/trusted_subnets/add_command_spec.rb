require_relative "../../../../spec_helper"
require "kontena/cli/grids/trusted_subnet_command"
require "kontena/cli/grids/trusted_subnets/add_command"

describe Kontena::Cli::Grids::TrustedSubnets::AddCommand do

  include ClientHelpers

  describe '#execute' do
    it 'requires api url' do
      expect(subject).to receive(:require_api_url).once
      subject.run(['grid', 'subnet'])
    end

    it 'requires token' do
      expect(subject).to receive(:require_token).and_return(token)
      subject.run(['grid', 'subnet'])
    end

    it 'requires grid as param' do
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
      subject.run(['test-grid', '10.12.0.0/19'])
    end
  end
end

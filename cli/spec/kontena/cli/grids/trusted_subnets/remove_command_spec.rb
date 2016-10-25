require_relative "../../../../spec_helper"
require "kontena/cli/grids/trusted_subnet_command"
require "kontena/cli/grids/trusted_subnets/remove_command"

describe Kontena::Cli::Grids::TrustedSubnets::RemoveCommand do

  include ClientHelpers

  describe '#execute' do
    it 'requires api url' do
      expect(subject).to receive(:require_api_url).once
      subject.run(['--force', 'grid', 'subnet'])
    end

    it 'requires token' do
      expect(subject).to receive(:require_token).and_return(token)
      subject.run(['--force', 'grid', 'subnet'])
    end

    it 'requires grid as param' do
      expect {
        subject.run([])
      }.to raise_error(Clamp::UsageError)
    end

    it 'removes subnet from grid' do
      allow(client).to receive(:get).with("grids/my-grid").and_return(
        'trusted_subnets' => ['192.168.12.0/24', '192.168.50.0/24']
      )
      expect(client).to receive(:put).with(
        'grids/my-grid', hash_including({trusted_subnets: [
          '192.168.12.0/24'
        ]})
      )
      subject.run(['--force', 'my-grid', '192.168.50.0/24'])
    end
  end
end

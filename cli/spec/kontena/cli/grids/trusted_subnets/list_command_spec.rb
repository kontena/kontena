require_relative "../../../../spec_helper"
require "kontena/cli/grids/trusted_subnet_command"
require "kontena/cli/grids/trusted_subnets/list_command"

describe Kontena::Cli::Grids::TrustedSubnets::ListCommand do

  include ClientHelpers

  describe '#execute' do
    it 'requires api url' do
      expect(subject.class.requires_current_master).to be_truthy
      subject.run(['grid'])
    end

    it 'requires token' do
      expect(subject.class.requires_current_master_token).to be_truthy
      subject.run(['grid'])
    end

    it 'requires grid as param' do
      expect {
        subject.run([])
      }.to raise_error(Clamp::UsageError)
    end

    it 'requests grid details from master' do
      expect(client).to receive(:get).with("grids/test-grid")
      subject.run(['test-grid'])
    end
  end
end

require_relative "../../../../spec_helper"
require "kontena/cli/grids/trusted_subnet_command"
require "kontena/cli/grids/trusted_subnets/list_command"

describe Kontena::Cli::Grids::TrustedSubnets::ListCommand do

  include ClientHelpers

  describe '#execute' do
    it 'requires api url' do
      expect(subject).to receive(:require_api_url).once
      subject.run(['grid'])
    end

    it 'requires token' do
      expect(subject).to receive(:require_token).and_return(token)
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

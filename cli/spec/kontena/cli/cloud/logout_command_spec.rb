require 'kontena/cli/cloud/logout_command'

describe Kontena::Cli::Cloud::LogoutCommand do

  include ClientHelpers

  let(:account) do
    spy
  end

  let(:subject) do
    described_class.new(File.basename($0))
  end

  describe '#logout' do
    before(:each) do
      allow(Kontena::Cli::Config.instance).to receive(:accounts).and_return([account])
    end

    it 'reads accounts from config' do
      expect(Kontena::Cli::Config.instance).to receive(:accounts).and_return([account])
      subject.run([])
    end

    it 'invalidates refresh_token' do
      expect(subject).to receive(:use_refresh_token).with(account)
      subject.run([])
    end

    it 'writes config file' do
      allow(subject).to receive(:use_refresh_token).with(account)
      expect(Kontena::Cli::Config.instance).to receive(:write)
      subject.run([])
    end
  end
end

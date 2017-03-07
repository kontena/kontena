require 'kontena/cli/master/logout_command'

describe Kontena::Cli::Master::LogoutCommand do

  include ClientHelpers

  let(:server) do
    spy('server')
  end

  let(:subject) do
    described_class.new(File.basename($0))
  end

  describe '#logout' do
    context 'with all options' do
      before(:each) do
        allow(Kontena::Cli::Config.instance).to receive(:servers).and_return([server])
        allow(Kontena::Cli::Config.instance).to receive(:write)
        allow(server).to receive(:token=).with(nil)
      end

      it 'reads servers from config' do
        expect(Kontena::Cli::Config.instance).to receive(:servers).and_return([server])
        subject.run(['--all'])
      end

      it 'invalidates refresh_token for each server' do
        expect(subject).to receive(:use_refresh_token).with(server)
        subject.run(['--all'])
      end

      it 'clears token' do
        expect(server).to receive(:token=).with(nil)
        subject.run(['--all'])
      end

      it 'writes config file' do
        allow(subject).to receive(:use_refresh_token).with(server)
        expect(Kontena::Cli::Config.instance).to receive(:write)
        subject.run(['--all'])
      end
    end

    context 'without all options' do
      before(:each) do
        allow(Kontena::Cli::Config.instance).to receive(:current_master).and_return(server)
        allow(Kontena::Cli::Config.instance).to receive(:write)
        allow(server).to receive(:token=).with(nil)
      end

      it 'reads current master from config' do
        expect(Kontena::Cli::Config.instance).to receive(:current_master).and_return(server)
        subject.run([])
      end

      it 'invalidates refresh_token for current master' do
        expect(subject).to receive(:use_refresh_token).with(server)
        subject.run([])
      end

      it 'clears token' do
        allow(subject).to receive(:use_refresh_token).with(server)
        expect(server).to receive(:token=).with(nil)
        subject.run([])
      end

      it 'writes config file' do
        allow(subject).to receive(:use_refresh_token).with(server)
        expect(Kontena::Cli::Config.instance).to receive(:write)
        subject.run([])
      end
    end

    context 'current master is not selected' do
      it 'outputs warning' do
        allow(Kontena::Cli::Config.instance).to receive(:current_master).and_return(nil)
        expect {
          subject.run([])
        }.to output("Current master has not been selected\n").to_stderr
      end
    end
  end
end

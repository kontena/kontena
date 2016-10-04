require_relative "../../../spec_helper"
require "kontena/cli/apps/scale_command"

describe Kontena::Cli::Apps::ScaleCommand do
  include FixturesHelpers
  include ClientHelpers

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:kontena_yml) do
    fixture('wordpress-scaled.yml')
  end

  let(:kontena_yml_no_instances) do
    fixture('wordpress.yml')
  end

  describe '#execute' do
    before(:each) do
      allow(subject).to receive(:current_dir).and_return("kontena-test")
      allow(File).to receive(:exists?).and_return(true)
      allow(File).to receive(:read).with("#{Dir.getwd}/kontena.yml").and_return(kontena_yml)
    end

    context 'when service already contains instances property' do
      it 'aborts execution' do
        expect{
          subject.run(['wordpress', 3])
        }.to raise_error(SystemExit)
      end
    end

    context 'when service not found in YML' do
      it 'aborts execution' do
        expect{
          subject.run(['mysql', 3])
        }.to raise_error(SystemExit)
      end
    end

    it 'scales given service' do
      allow(File).to receive(:read).with("#{Dir.getwd}/kontena.yml").and_return(kontena_yml_no_instances)
      expect(subject).to receive(:scale_service).with(duck_type(:access_token),'kontena-test-wordpress',3)
      subject.run(['wordpress', 3])
    end

  end
end

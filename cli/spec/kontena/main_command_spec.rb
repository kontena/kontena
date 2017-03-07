require 'kontena/main_command'

describe Kontena::MainCommand do
  let(:subject) { described_class.new('kontena') }

  describe '--version' do
    it 'outputs the version number and exits' do
      expect do
        expect{subject.run(['--version'])}.to output(/kontena-cli #{Kontena::Cli::VERSION}/).to_stdout
      end.to raise_error(SystemExit) do |exc|
        expect(exc.status).to eq 0
      end
    end
  end
end

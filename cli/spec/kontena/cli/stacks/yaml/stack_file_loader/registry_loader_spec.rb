require 'kontena/stacks_cache'
require 'yaml'

describe Kontena::Cli::Stacks::YAML::RegistryLoader do
  include FixturesHelpers

  before do
    allow(File).to receive(:exist?).and_return(false)
  end

  describe '#match' do
    it 'returns false when input is not a registry path' do
      expect(described_class.match?('foofoo')).to be_falsey
    end

    it 'returns true when file exists' do
      expect(described_class.match?('user/stack')).to be_truthy
      expect(described_class.match?('user/stack:1.0.0')).to be_truthy
    end
  end

  describe 'instance methods' do
    let(:subject) { described_class.new('user/stack') }

    before do
      allow(Kontena::StacksCache).to receive(:pull).with('user/stack').and_return(
        fixture('kontena_v3.yml')
      )
    end

    describe '#read_content' do
      it 'reads the file' do
        allow(Kontena::Cli::Config).to receive(:current_account).and_return(double(stacks_url: 'foo'))
        expect(subject.read_content).to match /^stack:/
      end
    end

    describe '#origin' do
      it 'returns "uri"' do
        expect(subject.origin).to eq 'registry'
      end
    end

    describe '#registry' do
      it 'returns "file://"' do
        allow(Kontena::Cli::Config).to receive(:current_account).and_return(double(stacks_url: 'foo'))
        expect(subject.registry).to eq 'foo'
      end
    end
  end
end



require 'kontena/cli/stacks/yaml/stack_file_loader'

describe Kontena::Cli::Stacks::YAML::FileLoader do
  include FixturesHelpers

  describe '#match' do
    it 'returns false when file does not exist' do
      expect(File).to receive(:exist?).and_return(false)
      expect(described_class.match?('foofoo')).to be_falsey
    end

    it 'returns true when file exists' do
      expect(File).to receive(:exist?).and_return(true)
      expect(described_class.match?('foofoo')).to be_truthy
    end
  end

  describe '#with_context' do
    it 'absolutizes paths' do
      some_file = Dir.glob('*').first
      expect(described_class.with_context(some_file)).to eq File.absolute_path(some_file)
    end
  end

  describe 'instance methods' do
    let(:subject) { described_class.new(fixture_path('kontena_v3.yml')) }

    describe '#read_content' do
      it 'reads the file' do
        expect(File).to receive(:read).with(fixture_path('kontena_v3.yml')).and_call_original
        expect(subject.read_content).to match /^stack:/
      end
    end

    describe '#origin' do
      it 'returns "file"' do
        expect(subject.origin).to eq 'file'
      end
    end

    describe '#registry' do
      it 'returns "file://"' do
        expect(subject.registry).to eq 'file://'
      end
    end
  end
end

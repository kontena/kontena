require 'kontena/cli/stacks/yaml/stack_file_loader'
require 'yaml'

describe Kontena::Cli::Stacks::YAML::UriLoader do
  include FixturesHelpers

  before do
    allow(File).to receive(:exist?).and_return(false)
  end

  describe '#match' do
    it 'returns false when input is not an url' do
      expect(described_class.match?('foofoo')).to be_falsey
    end

    it 'returns true when file exists' do
      expect(described_class.match?('http://foofoo')).to be_truthy
    end
  end

  describe 'instance methods' do
    let(:subject) { described_class.new('http://foofoo/foo.yml') }

    before do
      stub_request(:get, 'http://foofoo/foo.yml').to_return(
        status: 200,
        headers: {
          'Content-Type' => 'application/yml',
        },
        body: fixture('kontena_v3.yml')
      )
    end

    describe '#read_content' do
      it 'reads the file' do
        expect(subject.read_content).to match /^stack:/
      end
    end

    describe '#origin' do
      it 'returns "uri"' do
        expect(subject.origin).to eq 'uri'
      end
    end

    describe '#registry' do
      it 'returns "file://"' do
        expect(subject.registry).to eq 'file://'
      end
    end
  end
end


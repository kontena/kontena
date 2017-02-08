require 'opto'
require 'kontena/cli/stacks/yaml/opto/service_link_resolver'

describe Kontena::Cli::Stacks::YAML::Opto::Resolvers::ServiceLink do
  let(:subject) do
    described_class.new({'prompt' => 'foo'})
  end

  describe '#resolve' do
    it 'returns nil if no matching services' do
      expect(subject).to receive(:get_services).and_return([])
      expect(subject).not_to receive(:prompt)
      expect(subject.resolve).to be_nil
    end

    it 'prompts user if matching services' do
      prompt = double(:prompt)
      allow(subject).to receive(:prompt).and_return(prompt)
      expect(prompt).to receive(:select).and_return('null/bar')
      expect(subject).to receive(:get_services).and_return([
        {'id' => 'foo/null/bar'}
      ])
      expect(subject.resolve).to eq('null/bar')
    end
  end

  describe '#default_index' do
    let(:option) do
      ::Opto::Option.new(default: 'foo/bar')
    end
    let(:subject) do
      described_class.new({'prompt' => 'foo'}, option)
    end

    it 'returns matching index' do
      services = [
        {'id' => 'test/foo/foo'},
        {'id' => 'test/foo/bar'},
        {'id' => 'test/asd/asd'}
      ]
      index = subject.default_index(services)
      expect(index).to eq(2)
    end

    it 'returns 0 if no matches' do
      services = [
        {'id' => 'test/foo/foo'},
        {'id' => 'test/asd/asd'}
      ]
      index = subject.default_index(services)
      expect(index).to eq(0)
    end
  end
end

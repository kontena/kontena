require 'opto'
require 'kontena/cli/stacks/yaml/opto/vault_cert_prompt_resolver'

describe Kontena::Cli::Stacks::YAML::Opto::Resolvers::VaultCertPrompt do

  before(:each) do
    allow(subject).to receive(:current_master).and_return("foo")
    allow(subject).to receive(:current_grid).and_return("foo")
  end

  describe '#resolve' do
    it 'returns nil if no matching secrets' do
      expect(subject).to receive(:get_secrets).and_return([])
      expect(subject).not_to receive(:prompt)
      expect(subject.resolve).to be_nil
    end

    it 'prompts user if matching secrets' do
      prompt = double(:prompt)
      allow(subject).to receive(:prompt).and_return(prompt)
      expect(prompt).to receive(:multi_select).and_return('ssl-cert')
      expect(subject).to receive(:get_secrets).and_return([{'name' => 'ssl-cert'}])
      subject.resolve
    end
  end

  describe '#default_indexes' do
    let(:option) do
      Opto::Option.new(default: ['ssl-cert-1', 'ssl-cert-3'])
    end

    let(:subject) do
      described_class.new('foo', option)
    end

    it 'returns all default indexes if found' do
      secrets = [
        {'name' => 'ssl-cert-1'},
        {'name' => 'ssl-cert-2'},
        {'name' => 'ssl-cert-3'}
      ]
      indexes = subject.default_indexes(secrets)
      expect(indexes).to eq([1, 3])
    end

    it 'returns partially found defaults' do
      secrets = [
        {'name' => 'ssl-cert-a'},
        {'name' => 'ssl-cert-b'},
        {'name' => 'ssl-cert-3'}
      ]
      indexes = subject.default_indexes(secrets)
      expect(indexes).to eq([3])
    end

    it 'returns empty array if no matches' do
      secrets = [
        {'name' => 'ssl-cert-a'}
      ]
      indexes = subject.default_indexes(secrets)
      expect(indexes).to eq([])
    end

    it 'returns empty array if no secrets' do
      secrets = []
      indexes = subject.default_indexes(secrets)
      expect(indexes).to eq([])
    end

    it 'returns empty array if no defaults' do
      secrets = [
        {'name' => 'ssl-cert-a'}
      ]
      allow(subject.option).to receive(:default).and_return([])
      indexes = subject.default_indexes(secrets)
      expect(indexes).to eq([])
    end
  end
end

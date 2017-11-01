require 'opto'
require 'kontena/cli/stacks/yaml/opto/certificates_resolver'

describe Kontena::Cli::Stacks::YAML::Opto::Resolvers::Certificates do
  let(:client) { instance_double(Kontena::Client) }
  let(:prompt) { double(:prompt) }
  let(:prompt_menu) { double(:prompt_menu) }

  let(:option_hint) { "Select SSL certificates" }
  let(:option_default) { nil }
  let(:option) { Opto::Option.new(default: option_default) }
  subject { described_class.new(option_hint, option) }

  before do
    allow(subject).to receive(:current_master).and_return("test-master")
    allow(subject).to receive(:current_grid).and_return("test-grid")
    allow(subject).to receive(:client).and_return(client)
    allow(subject).to receive(:prompt).and_return(prompt)
  end

  context 'with grid certificates' do
    let(:certificates) { [
      { 'subject' => 'test.example.com' },
      { 'subject' => 'test-2.example.com' },
    ] }

    before do
      allow(client).to receive(:get).with('grids/test-grid/certificates').and_return('certificates' => certificates)
    end

    it 'lists grid certificates and prompts' do
      expect(prompt).to receive(:multi_select).with(option_hint) do |&block|
        expect(prompt_menu).to_not receive(:default)
        expect(prompt_menu).to receive(:choice).with('test.example.com')
        expect(prompt_menu).to receive(:choice).with('test-2.example.com')

        block.call(prompt_menu)

        'test.example.com'
      end

      expect(subject.resolve).to eq 'test.example.com'
    end
  end
end

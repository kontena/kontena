require 'opto'
require 'kontena_cli'
require 'kontena/cli/stacks/yaml/opto'

describe Kontena::Cli::Stacks::YAML::Prompt do

  describe 'echoing' do
    let(:option_without_echo) { Opto::Option.new(type: 'string', name: 'foo', from: 'prompt', echo: false) }
    let(:option_with_echo) { Opto::Option.new(type: 'string', name: 'foo', from: 'prompt') }
    let(:prompt) { double(:prompt) }

    before(:each) do
      allow(Kontena).to receive(:prompt).and_return(prompt)
    end

    it 'turns echo off when variable has "echo: false"' do
      expect(prompt).to receive(:ask).with(/Enter/, hash_including(echo: false))
      option_without_echo.value
    end

    it 'keeps echo on when variable does not have "echo: false"' do
      expect(prompt).to receive(:ask).with(/Enter/, hash_not_including(echo: false))
      option_with_echo.value
    end
  end
end


require_relative "../../../spec_helper"
require "kontena/cli/stacks/upgrade_command"

describe Kontena::Cli::Stacks::UpgradeCommand do

  include ClientHelpers

  describe '#execute' do

    let(:stack) do
      {
        'name' => 'stack-a',
        'services' => []
      }
    end

    it 'requires api url' do
      allow(subject).to receive(:stack_from_yaml).with('kontena.yml').and_return(stack)
      expect(subject).to receive(:require_api_url).once
      subject.run(['stack-name', './path/to/kontena.yml'])
    end

    it 'requires token' do
      allow(subject).to receive(:stack_from_yaml).with('kontena.yml').and_return(stack)
      expect(subject).to receive(:require_token).and_return(token)
      subject.run(['stack-name', './path/to/kontena.yml'])
    end

    it 'sends stack to master' do
      
      allow(subject).to receive(:require_config_file).with('./path/to/kontena.yml').and_return(true)
      allow(subject).to receive(:stack_from_yaml).with('./path/to/kontena.yml').and_return(stack)
      expect(client).to receive(:put).with(
        'stacks/test-grid/stack-a', anything
      )
      subject.run(['stack-a', './path/to/kontena.yml'])
    end

    it 'allows to override stack name' do
      allow(subject).to receive(:require_config_file).with('./path/to/kontena.yml').and_return(true)
      allow(subject).to receive(:stack_from_yaml).with('./path/to/kontena.yml').and_return(stack)
      stack_b = stack
      stack_b[:name] = 'stack-b'
      expect(client).to receive(:put).with(
        'stacks/test-grid/stack-b', anything
      )
      subject.run(['stack-b',  './path/to/kontena.yml'])
    end
  end
end

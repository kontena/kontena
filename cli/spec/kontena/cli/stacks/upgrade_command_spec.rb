require_relative "../../../spec_helper"
require "kontena/cli/stacks/upgrade_command"

describe Kontena::Cli::Stacks::UpgradeCommand do

  include ClientHelpers
  include RequirementsHelper

  mock_current_master

  describe '#execute' do

    let(:stack) do
      {
        'name' => 'stack-a',
        'services' => []
      }
    end

    let(:defaults) do
      { 'foo' => 'bar' }
    end

    let(:stack_response) do
      {
        'name' => 'stack-a',
        'services' => [],
        'variables' => defaults
      }
    end

    before(:each) do
      allow(File).to receive(:exist?).with('./path/to/kontena.yml').and_return(true)
    end

    expect_to_require_current_master
    expect_to_require_current_master_token

    it 'requires stack file' do
      expect(client).to receive(:get).with('stacks/test-grid/stack-name').and_return(stack_response)
      allow(subject).to receive(:stack_from_yaml).with('./path/to/kontena.yml', name: 'stack-name', values: nil, from_registry: false, defaults: defaults).and_return(stack)
      expect(subject).to receive(:require_config_file).with('./path/to/kontena.yml').at_least(:once).and_return(true)
      subject.run(['stack-name', './path/to/kontena.yml'])
    end

    it 'uses kontena.yml as default stack file' do
      expect(client).to receive(:get).with('stacks/test-grid/stack-name').and_return(stack_response)
      expect(subject).to receive(:stack_from_yaml).with('kontena.yml', name: 'stack-name', values: nil, from_registry: nil, defaults: defaults).and_return(stack)
      subject.run(['stack-name'])
    end

    it 'sends stack to master' do
      expect(client).to receive(:get).with('stacks/test-grid/stack-a').and_return(stack_response)
      allow(subject).to receive(:require_config_file).with('./path/to/kontena.yml').and_return(true)
      allow(subject).to receive(:stack_from_yaml).with('./path/to/kontena.yml', name: 'stack-a', values: nil, from_registry: false, defaults: defaults).and_return(stack)
      expect(client).to receive(:put).with(
        'stacks/test-grid/stack-a', anything
      )
      subject.run(['stack-a', './path/to/kontena.yml'])
    end

    it 'allows to override stack name' do
      expect(client).to receive(:get).with('stacks/test-grid/stack-b').and_return(stack_response)
      allow(subject).to receive(:require_config_file).with('./path/to/kontena.yml').and_return(true)
      allow(subject).to receive(:stack_from_yaml).with('./path/to/kontena.yml', name: 'stack-b', values: nil, from_registry: false, defaults: defaults).and_return(stack)
      stack_b = stack
      stack_b[:name] = 'stack-b'
      expect(client).to receive(:put).with(
        'stacks/test-grid/stack-b', anything
      )
      subject.run(['stack-b',  './path/to/kontena.yml'])
    end

    context '--deploy option' do
      context 'when given' do
        it 'triggers deploy' do
          expect(client).to receive(:get).with('stacks/test-grid/stack-a').and_return(stack_response)
          allow(subject).to receive(:require_config_file).with('./path/to/kontena.yml').and_return(true)
          allow(subject).to receive(:stack_from_yaml).with('./path/to/kontena.yml', name: 'stack-a', values: nil, from_registry: false, defaults: defaults).and_return(stack)
          allow(client).to receive(:put).with(
            'stacks/test-grid/stack-a', anything
          ).and_return({})
          expect(Kontena).to receive(:run).with("stack deploy stack-a").once
          subject.run(['--deploy', 'stack-a', './path/to/kontena.yml'])
        end
      end
      context 'when not given' do
        it 'does not trigger deploy' do
          expect(client).to receive(:get).with('stacks/test-grid/stack-a').and_return(stack_response)
          allow(subject).to receive(:require_config_file).with('./path/to/kontena.yml').and_return(true)
          allow(subject).to receive(:stack_from_yaml).with('./path/to/kontena.yml', name: 'stack-a', values: nil, from_registry: false, defaults: defaults).and_return(stack)
          allow(client).to receive(:put).with(
            'stacks/test-grid/stack-a', anything
          ).and_return({})
          expect(Kontena).not_to receive(:run).with("stack deploy stack-a")
          subject.run(['stack-a', './path/to/kontena.yml'])
        end
      end
    end
  end
end

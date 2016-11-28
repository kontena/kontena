require_relative "../../../spec_helper"
require "kontena/cli/stacks/install_command"

describe Kontena::Cli::Stacks::InstallCommand do

  include ClientHelpers

  describe '#execute' do
    let(:stack) do
      {
        name: 'stack-a',
        registry: 'file://kontena.yml',
        source: "YAML content",
        services: []
      }
    end

    before(:each) do
      allow(subject).to receive(:yaml_content).and_return("YAML content")
    end

    it 'requires api url' do
      allow(subject).to receive(:stack_from_yaml).with('kontena.yml').and_return(stack)
      expect(described_class.requires_current_master?).to be_truthy
      subject.run([])
    end

    it 'requires token' do
      allow(subject).to receive(:stack_from_yaml).with('kontena.yml').and_return(stack)
      expect(described_class.requires_current_master_token?).to be_truthy
      subject.run([])
    end

    it 'sends stack to master' do
      allow(subject).to receive(:require_config_file).with('kontena.yml').and_return(true)
      allow(subject).to receive(:stack_from_yaml).with('kontena.yml').and_return(stack)
      expect(client).to receive(:post).with(
        'grids/test-grid/stacks', stack
      )
      subject.run([])
    end

    it 'allows to override stack name' do
      allow(subject).to receive(:require_config_file).with('kontena.yml').and_return(true)
      allow(subject).to receive(:stack_from_yaml).with('kontena.yml').and_return(stack)
      stack_b = stack
      stack_b[:name] = 'stack-b'
      expect(client).to receive(:post).with(
        'grids/test-grid/stacks', stack
      )
      subject.run(['--name', 'stack-b'])
    end
  end
end

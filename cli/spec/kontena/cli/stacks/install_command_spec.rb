require "kontena/cli/stacks/install_command"

describe Kontena::Cli::Stacks::InstallCommand do

  include ClientHelpers
  include RequirementsHelper
  mock_current_master

  describe '#execute' do
    let(:stack) do
      {
        name: 'stack-a',
        stack: 'user/stack-a',
        version: '1.0.0',
        registry: 'file://kontena.yml',
        source: "YAML content",
        services: []
      }
    end

    let(:stack_with_messages) do
      stack.merge(
        services: [
          {
            'name' => 'wordpress',
            'hooks' => {
              'post_install' => [
                { 'message' => 'Hello from post install' }
              ]
            }
          }
        ]
      )
    end

    expect_to_require_current_master
    expect_to_require_current_master_token

    before(:each) do
      allow(subject).to receive(:yaml_content).and_return("YAML content")
    end

    it 'sends stack to master' do
      allow(File).to receive(:exist?).with('kontena.yml').and_return(true)
      allow(subject).to receive(:require_config_file).with('kontena.yml').and_return(true)
      allow(subject).to receive(:stack_read_and_dump).with('kontena.yml', hash_including(name: nil, values: nil)).and_return(stack)
      expect(client).to receive(:post).with(
        'grids/test-grid/stacks', stack
      )
      subject.run([])
    end

    it 'allows to override stack name' do
      allow(File).to receive(:exist?).with('kontena.yml').and_return(true)
      allow(subject).to receive(:require_config_file).with('kontena.yml').and_return(true)
      allow(subject).to receive(:stack_read_and_dump).with('kontena.yml', hash_including(name: 'stack-b', values: nil)).and_return(stack)
      stack_b = stack
      stack_b[:name] = 'stack-b'
      expect(client).to receive(:post).with(
        'grids/test-grid/stacks', stack
      )
      subject.run(['--name', 'stack-b'])
    end

    it 'accepts a stack name as filename' do
      expect(File).to receive(:exist?).with('user/stack:1.0.0').and_return(false)
      expect(subject).to receive(:stack_read_and_dump).with('user/stack:1.0.0', name: nil, values: nil).and_return(stack)
      expect(client).to receive(:post).with(
        'grids/test-grid/stacks', stack
      )
      subject.run(['user/stack:1.0.0'])
    end

    it 'displays post install messages' do
      allow(File).to receive(:exist?).with('kontena.yml').and_return(true)
      allow(subject).to receive(:require_config_file).with('kontena.yml').and_return(true)
      allow(subject).to receive(:stack_from_yaml).and_return(stack_with_messages)
      allow(client).to receive(:post).and_return(true)
      expect{subject.run(['user/stack:1.0.0'])}.to output(/Hello from post install/).to_stdout
    end
  end
end

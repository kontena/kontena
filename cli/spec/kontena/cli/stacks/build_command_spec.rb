require "kontena/cli/stacks/build_command"

describe Kontena::Cli::Stacks::BuildCommand do

  include RequirementsHelper

  mock_current_master

  before(:each) do
    ENV['STACK'] = nil
  end

  let(:subject) do
    described_class.new(File.basename($0))
  end

  describe '#execute' do
    let(:stack) do
      {
        'name' => 'stack-a',
        'stack' => 'user/stack-a',
        'version' => '1.0.0',
        'services' => [
          service
        ]
      }
    end

    let(:service) do
      {
        'name' => 'test',
        'image' => 'registry.kontena.local/test:latest',
        'build' => {
          'context' => File.expand_path('.')
        }
      }
    end

    before(:each) do
      allow(subject).to receive(:stack_name).and_return('stack-a')
      allow(subject).to receive(:stack).and_return(stack)
      allow(subject).to receive(:system).and_return(true)
    end

    expect_to_require_current_master
    expect_to_require_current_master_token

    it 'builds docker image' do
      expect(subject).to receive(:system).with('docker', 'build', '-t', 'registry.kontena.local/test:latest', '--pull', File.expand_path('.'))
      subject.run([])
    end

    it 'pushes docker image' do
      expect(subject).to receive(:system).with('docker', 'push', 'registry.kontena.local/test:latest')
      subject.run([])
    end

    it 'uses sudo when --sudo given' do
      expect(subject).to receive(:system).with('sudo', 'docker', 'build', '-t', 'registry.kontena.local/test:latest', '--pull', File.expand_path('.')).and_return(true)
      expect(subject).to receive(:system).with('sudo', 'docker', 'push', 'registry.kontena.local/test:latest').and_return(true)
      subject.run(['--sudo'])
    end
  end
end

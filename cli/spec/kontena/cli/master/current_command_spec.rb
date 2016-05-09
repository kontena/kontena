require_relative "../../../spec_helper"
require 'kontena/cli/master/current_command'

describe Kontena::Cli::Master::CurrentCommand do
  let(:settings) do
    {'current_server' => 'alias',
      'servers' => [
        {'name' => 'some_master', 'url' => 'some_master'},
        {'name' => 'alias', 'url' => 'someurl', 'token' => '123456'}
      ]
    }
  end

  let(:subject) { described_class.new(File.basename($0)) }

  describe '#execute' do
    it 'puts master name and URL' do
      allow(subject).to receive(:settings).and_return(settings)

      expect {
        subject.run([])
      }.to output(/alias.*someurl/).to_stdout
    end

    it 'only outputs name if name-flag is set' do
      allow(subject).to receive(:settings).and_return(settings)

      expect {
        subject.run(['--name'])
      }.to output("alias\n").to_stdout
    end

    it 'does not raise error when logged in' do
      allow(subject).to receive(:settings).and_return(settings)

      expect {
        subject.run([])
      }.to_not raise_error
    end

    it 'raises error when not logged in' do
      allow(subject).to receive(:settings).and_return(
        {
            'current_server' => nil,
            'servers' => [
                {'name' => 'some_master', 'url' => 'some_master'},
                {'name' => 'alias', 'url' => 'someurl', 'token' => '123456'}
            ]
        }
      )

      expect {
        subject.run([])
      }.to raise_error(ArgumentError)
    end
  end
end

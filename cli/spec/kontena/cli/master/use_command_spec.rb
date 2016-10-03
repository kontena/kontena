require_relative "../../../spec_helper"
require 'kontena/cli/master/use_command'

describe Kontena::Cli::Master::UseCommand do

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:client) { spy(:client) }

  let(:valid_settings) do
    {'current_server' => 'alias',
     'servers' => [
         {'name' => 'some_master', 'url' => 'some_master'},
         {'name' => 'alias', 'url' => 'someurl', 'token' => '123456'}
     ]
    }
  end

  describe '#use' do
    it 'should update current master' do
      allow(subject).to receive(:client).and_return(client)
      allow(subject).to receive(:settings).and_return(valid_settings)
      expect(subject).to receive(:current_master=).with('some_master')
      subject.run(['some_master'])
    end

    it 'should fetch grid list from master' do
      allow(subject).to receive(:require_token).and_return('token')
      allow(subject).to receive(:client).and_return(client)
      allow(subject).to receive(:settings).and_return(valid_settings)
      expect(subject).to receive(:current_master=).with('some_master')
      expect(client).to receive(:get).with('grids')
      subject.run(['some_master'])
    end

    it 'should abort with error message if master is not configured' do
      expect { subject.run(['not_existing']) }.to raise_error(
        SystemExit, /Could not resolve master with name: not_existing/)
    end
  end
end

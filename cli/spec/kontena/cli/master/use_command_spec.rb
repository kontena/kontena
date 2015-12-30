require_relative "../../../spec_helper"
require 'kontena/cli/master/use_command'

describe Kontena::Cli::Master::UseCommand do

  let(:subject) do
    described_class.new(File.basename($0))
  end

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
      allow(subject).to receive(:settings).and_return(valid_settings)
      expect(subject).to receive(:current_master=).with('some_master')
      subject.run(['some_master'])
    end

  end

end
require_relative "../../spec_helper"
require "kontena/cli/common"

describe Kontena::Cli::Common do
  let(:subject) do
    Class.new do
      include Kontena::Cli::Common
    end.new
  end

  before(:each) do
    allow(subject).to receive(:settings).and_return({'current_server' => 'default',
                                                     'servers' => [{}]
                                                    })
    allow(subject).to receive(:save_settings)
  end

  describe '#current_grid' do
    it 'returns nil by default' do
      allow(subject).to receive(:settings).and_return({'current_server' => 'alias',
                                                       'servers' => [
                                                           {'name' => 'some_master', 'url' => 'some_master'},
                                                           {'name' => 'alias', 'url' => 'someurl'}
                                                       ]
                                                      })
      expect(subject.current_grid).to eq(nil)
    end

    it 'returns grid from env' do
      expect(ENV).to receive(:[]).with('KONTENA_GRID').and_return('foo')
      expect(subject.current_grid).to eq('foo')
    end

    it 'returns grid from json' do
      allow(subject).to receive(:settings).and_return({'current_server' => 'alias',
                                                       'servers' => [
                                                           {'name' => 'some_master', 'url' => 'some_master'},
                                                           {'name' => 'alias', 'url' => 'someurl', 'grid' => 'foo_grid'}
                                                       ]
                                                      })
      expect(subject.current_grid).to eq('foo_grid')
    end

    it 'returns nil if settings are not present' do
      allow(subject).to receive(:current_master).and_raise(ArgumentError)
      expect(subject.current_grid).to be_nil
    end
  end

  describe '#api_url' do
    it 'raises error by default' do
      expect {
        subject.api_url
      }.to raise_error(ArgumentError)
    end

    it 'return url from env' do
      expect(ENV).to receive(:[]).with('KONTENA_URL').and_return('https://domain.com')
      expect(subject.api_url).to eq('https://domain.com')
    end
  end

  describe '#require_token' do
    it 'raises error by default' do
      expect {
        subject.require_token
      }.to raise_error(ArgumentError)
    end

    it 'return token from env' do
      expect(ENV).to receive(:[]).with('KONTENA_TOKEN').and_return('secret_token')
      expect(subject.require_token).to eq('secret_token')
    end
  end

  describe '#current_master' do
    it 'return correct master info' do
      allow(subject).to receive(:settings).and_return({'current_server' => 'alias',
                                                       'servers' => [
                                                           {'name' => 'some_master', 'url' => 'some_master'},
                                                           {'name' => 'alias', 'url' => 'someurl'}
                                                       ]
                                                      })

      expect(subject.current_master['url']).to eq('someurl')
      expect(subject.current_master['name']).to eq('alias')
    end
  end

  describe '#settings' do
    it 'migrates old settings' do
      RSpec::Mocks.space.proxy_for(subject).reset

      allow(File).to receive(:exists?).and_return(true)
      allow(File).to receive(:read).and_return('{
        "server": {
          "url": "https://master.domain.com:8443",
          "grid": "my-grid",
          "token": "kontena-token"
        }
      }')
      expected_settings = {
          'current_server' => 'default',
          'servers' => [
              {
                  "url" => "https://master.domain.com:8443",
                  "grid" => "my-grid",
                  "token" => "kontena-token",
                  "name" => "default"
              }
          ]
      }
      expect(File).to receive(:write).with(subject.settings_filename, JSON.pretty_generate(expected_settings))

      subject.settings
    end

  end

  describe '#error' do
    it 'prints error message to stderr if given and raise error' do
      expect($stderr).to receive(:puts).with('error message!')
      expect{subject.error('error message!')}.to raise_error(SystemExit)
    end
  end

  describe '#confirm_command' do
    it 'returns true if input matches' do
      allow(subject).to receive(:prompt).and_return('name-to-confirm')

      expect(subject.confirm_command('name-to-confirm')).to be_truthy
      expect{subject.confirm_command('name-to-confirm')}.to_not raise_error
    end

    it 'raises error unless input matches' do
      expect(subject).to receive(:prompt).and_return('wrong-name')
      expect(subject).to receive(:error).with(/did not match/)

      subject.confirm_command('name-to-confirm')
    end
  end

  describe '#confirm' do
    it 'returns true if confirmed' do
      allow(subject).to receive(:prompt).and_return('y')

      expect(subject.confirm).to be_truthy
      expect{subject.confirm}.to_not raise_error
    end

    it 'raises error unless confirmed' do
      expect(subject).to receive(:prompt).and_return('ei')
      expect(subject).to receive(:error).with(/Aborted/)

      subject.confirm
    end
  end
end

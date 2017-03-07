require "kontena/cli/apps/config_command"
require 'ruby_dig'

describe Kontena::Cli::Apps::ConfigCommand do
  include FixturesHelpers

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:kontena_yml) do
    fixture('mysql.yml')
  end

  let(:yaml_with_app_name) do
    {
      'version' => '2',
      'name' => 'myapp',
      'services' => {
        'mysql' => {
          'image' => '$project-mysql:5.6'
        }
      }
    }
  end

  let(:settings) do
    {'current_server' => 'alias',
     'servers' => [
         {
           'name' => 'some_master',
           'url' => 'some_master'
         }
     ]
    }
  end

  describe '#execute' do
    before(:each) do
      allow(subject).to receive(:settings).and_return(settings)
      allow(subject).to receive(:current_dir).and_return("kontena-test")
      allow(File).to receive(:exists?).and_return(true)
      allow(File).to receive(:read).with("#{Dir.getwd}/kontena.yml").and_return(kontena_yml)
    end

    it 'outputs service configs' do
      valid_output = {
        'services' => {
          'mysql' => {
            'image' => 'mysql:5.6',
            'stateful' => false
          }
        }
      }
      expect {
        subject.run([])
      }.to output(valid_output.to_yaml).to_stdout
    end

    it 'uses app name from yaml as project variable' do

      allow(File).to receive(:read).with("#{Dir.getwd}/kontena.yml").and_return(yaml_with_app_name.to_yaml)
      valid_output = {
        'services' => {
          'mysql' => {
            'image' => 'myapp-mysql:5.6',
            'stateful' => false
          }
        }
      }
      expect {
        subject.run([])
      }.to output(valid_output.to_yaml).to_stdout
    end

  end
end

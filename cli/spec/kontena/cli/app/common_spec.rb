require_relative "../../../spec_helper"
require "kontena/cli/apps/common"

describe Kontena::Cli::Apps::Common do
  include ClientHelpers
  include FixturesHelpers

  let(:subject) do
    Class.new { include Kontena::Cli::Apps::Common}.new
  end

  let(:kontena_yml) do
    fixture('kontena.yml')
  end

  let(:docker_compose_yml) do
    fixture('docker-compose.yml')
  end

  let(:mysql_yml) do
    fixture('mysql.yml')
  end

  let(:services) do
    {
      'wordpress' => {
        'image' => 'wordpress:4.1',
        'ports' => ['80:80']
      }
    }
  end

  describe '#parse_services' do

    it 'returns services from given YAML file' do
      allow(File).to receive(:read).with("#{Dir.getwd}/kontena.yml").and_return(kontena_yml)
      allow(File).to receive(:read).with("#{Dir.getwd}/docker-compose.yml").and_return(docker_compose_yml)
      services = subject.parse_services('kontena.yml')
      expect(services['wordpress']).not_to be_nil
    end

    it 'raises error if extended service is not found from base file' do
      allow(File).to receive(:read).with("#{Dir.getwd}/kontena.yml").and_return(kontena_yml)
      allow(File).to receive(:read).with("#{Dir.getwd}/docker-compose.yml").and_return(mysql_yml)

      expect {
        subject.parse_services('kontena.yml')
      }.to raise_error(SystemExit)
    end
  end

  describe '#normalize_env_vars' do
    it 'converts env hash to array' do
      opts = {
          'environment' => {
              'FOO' => 'bar',
              'BAR' => 'baz'
          }
      }
      subject.normalize_env_vars(opts)
      env = opts['environment']
      expect(env).to include('FOO=bar')
      expect(env).to include('BAR=baz')
    end

    it 'does nothing to env array' do
      opts = {
          'environment' => [
              'FOO=bar', 'BAR=baz'
          ]
      }
      subject.normalize_env_vars(opts)
      env = opts['environment']
      expect(env).to include('FOO=bar')
      expect(env).to include('BAR=baz')
    end
  end

  describe '#extend_env_vars' do
    it 'inherites env vars from upper level' do
      from = {'environment' => ['FOO=bar']}
      to = {}
      env_vars = subject.extend_env_vars(from, to)
      expect(env_vars).to eq(['FOO=bar'])
    end

    it 'overrides values' do
      from = {'environment' => ['FOO=bar']}
      to = {'environment' => ['FOO=baz']}
      env_vars = subject.extend_env_vars(from, to)
      expect(env_vars).to eq(['FOO=baz'])
    end

    it 'combines variables' do
      from = {'environment' => ['FOO=bar']}
      to = {'environment' => ['BAR=baz']}
      env_vars = subject.extend_env_vars(from, to)
      expect(env_vars).to eq(['BAR=baz', 'FOO=bar'])
    end


  end
end
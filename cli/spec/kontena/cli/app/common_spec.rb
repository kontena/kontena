require_relative "../../../spec_helper"
require "kontena/cli/apps/common"

describe Kontena::Cli::Apps::Common do

  let(:subject) do
    Class.new { include Kontena::Cli::Apps::Common}.new
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
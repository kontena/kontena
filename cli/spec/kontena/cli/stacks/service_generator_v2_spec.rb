require "kontena/cli/stacks/service_generator_v2"
require 'ruby_dig'

describe Kontena::Cli::Stacks::ServiceGeneratorV2 do
  let(:subject) do
    described_class.new({})
  end

  describe '#parse_data' do
    it 'parses network_mode' do
      data = {
        'image' => 'wordpress:latest',
        'network_mode' => 'bridge'
      }
      result = subject.send(:parse_data, data)
      expect(result['net']).to eq('bridge')
    end

    it 'parses logging' do
      data = {
        'image' => 'wordpress:latest',
        'logging' => {
          'driver' => 'influxdb',
          'options' => {
            'syslog-address' => 'tcp://192.168.0.42:123'
          }
        }
      }
      result = subject.send(:parse_data, data)
      expect(result['log_driver']).to eq('influxdb')
      expect(result['log_opts']).to eq({
        'syslog-address' => 'tcp://192.168.0.42:123'
      })
    end

    it 'adds depends_on to links' do
      data = {
        'image' => 'wordpress:latest',
        'depends_on' => ['mysql']
      }
      result = subject.send(:parse_data, data)
      expect(result['links']).to eq([{
        'name' => 'mysql',
        'alias' => 'mysql'
      }])
    end
  end

  describe '#parse_build_options' do
    context 'when build option is a string' do
      it 'converts build option to hash' do
        data = {
          'build' => '.',
          'image' => 'myapp'
        }
        result = subject.send(:parse_build_options, data)
        expect(result).to eq({ 'context' => '.' })
      end
    end
    context 'when build options is a hash' do
      it 'uses it as build options' do
        data = {
          'build' => {
            'context' => '.',
            'dockerfile' => 'alternate-dockerfile'
           }
        }
        result = subject.send(:parse_build_options, data)
        expect(result).to eq(data['build'])
      end
    end
  end
end

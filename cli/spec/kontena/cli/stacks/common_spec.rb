require "kontena/cli/stacks/common"
require "kontena/cli/stacks/yaml/reader"

describe Kontena::Cli::Stacks::Common do
  include FixturesHelpers
  include RequirementsHelper
  include ClientHelpers

  mock_current_master

  let(:klass) do
    Class.new(Kontena::Command) do
      include Kontena::Cli::Stacks::Common
      include Kontena::Cli::Common
      include Kontena::Cli::Stacks::Common::StackFileOrNameParam
      include Kontena::Cli::Stacks::Common::StackNameOption
      include Kontena::Cli::Stacks::Common::StackValuesToOption
      include Kontena::Cli::Stacks::Common::StackValuesFromOption
    end
  end

  let(:subject) { klass.new('kontena') }

  before do
    allow(ENV).to receive(:[]).with('GRID').and_return('test-grid')
    allow(ENV).to receive(:[]).with('STACK').and_return('test-stack')
  end

  describe '#loader' do
    it 'returns a loader' do
      expect(subject.instance([fixture_path('kontena_v3.yml')]).loader).to respond_to(:reader)
      expect(subject.instance([fixture_path('kontena_v3.yml')]).loader).to respond_to(:dependencies)
      expect(subject.instance([fixture_path('kontena_v3.yml')]).loader).to respond_to(:stack_name)
    end
  end

  describe '#reader' do
    it 'returns a YAML reader for the stack file param' do
      expect(subject.instance([fixture_path('kontena_v3.yml')]).reader).to respond_to(:execute)
      expect(subject.instance([fixture_path('kontena_v3.yml')]).reader).to respond_to(:variable_values)
    end
  end

  describe '#stack' do
    it 'returns a stack result' do
      expect(subject.instance([fixture_path('kontena_v3.yml')]).stack).to respond_to(:[])
      expect(subject.instance([fixture_path('kontena_v3.yml')]).stack['name']).to eq ::YAML.safe_load(fixture('kontena_v3.yml'))['stack'].split('/').last
    end

    it 'sets the stack name' do
      expect(subject.instance(['-n', 'foo', fixture_path('kontena_v3.yml')]).stack['name']).to eq 'foo'
    end
  end

  describe '#values_from_options' do
    it 'is a hash that has key value pairs from -v params' do
      expect(subject.instance(['-v', 'foo=bar', '-v', 'bar=baz', fixture_path('kontena_v3.yml')]).values_from_options).to match hash_including('foo' => 'bar', 'bar' => 'baz')
    end

    describe '--values-from' do
      before do
        allow(File).to receive(:exist?).with('vars.yml').and_return(true)
        expect(File).to receive(:read).with('vars.yml').and_return(::YAML.dump('baz' => 'bag', 'bar' => 'boo'))
      end

      it 'includes values read from --values-from file' do
        expect(subject.instance(['--values-from', 'vars.yml', fixture_path('kontena_v3.yml')]).values_from_options).to match hash_including('baz' => 'bag', 'bar' => 'boo')
      end

      it 'includes values read from --values-from file, overriden by -v values' do
        expect(subject.instance(['-v', 'foo=bar', '-v', 'bar=baz', '--values-from', 'vars.yml', fixture_path('kontena_v3.yml')]).values_from_options).to match hash_including('foo' => 'bar', 'bar' => 'baz', 'baz' => 'bag')
      end
    end

    describe '--values-from-stack' do
      let(:instance) { subject.instance(['--values-from-stack', 'redisproxy', fixture_path('kontena_v3.yml')]) }

      it 'reads all dependent stack variables' do
        expect(client).to receive(:get).with('stacks/test-grid/redisproxy').and_return(
          'variables' => { 'foo' => 'bar' },
          'children' => [ { 'name' => 'redisproxy-redis1' } ]
        )

        expect(client).to receive(:get).with('stacks/test-grid/redisproxy-redis1').and_return(
          'variables' => { 'redisvar' => 'test' },
          'children' => [ { 'name' => 'redisproxy-redis1-monitor' } ]
        )

        expect(client).to receive(:get).with('stacks/test-grid/redisproxy-redis1-monitor').and_return(
          'variables' => { 'monitorvar' => 'test2' },
          'children' => []
        )

        expect(instance.values_from_options).to match hash_including('foo' => 'bar', 'redis1.redisvar' => 'test', 'redis1.monitor.monitorvar' => 'test2')
      end

    end
  end
end

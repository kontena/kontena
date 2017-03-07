require 'kontena/cli/apps/yaml/service_extender'

describe Kontena::Cli::Apps::YAML::ServiceExtender do
  let(:options) do
    {
      'image' => 'alpine:latest',
      'ports' => '80:80'
    }
  end

  let(:parent_options) do
    {
      'build' => '.'
    }
  end

  describe '#extend' do
    it 'merges options' do
      result = described_class.new(options).extend(parent_options)
      expected_result = {
        'image' => 'alpine:latest',
        'build' => '.',
        'ports' => '80:80',
        'environment' => [],
        'secrets' => []
      }
      expect(result).to eq(expected_result)
    end

    context 'environment variables' do
      it 'inherites env vars from upper level' do
        from = { 'environment' => ['FOO=bar'] }
        to = {}
        result = described_class.new(to).extend(from)
        expect(result['environment']).to eq(['FOO=bar'])
      end

      it 'overrides values' do
        from = { 'environment' => ['FOO=bar'] }
        to = { 'environment' => ['FOO=baz'] }
        result = described_class.new(to).extend(from)
        expect(result['environment']).to eq(['FOO=baz'])
      end

      it 'combines variables' do
        from = { 'environment' => ['FOO=bar'] }
        to = { 'environment' => ['BAR=baz'] }
        result = described_class.new(to).extend(from)
        expect(result['environment']).to eq(['BAR=baz', 'FOO=bar'])
      end
    end

    context 'secrets' do
      it 'inherites secrets from upper level' do
        secret = {
          'secret' => 'CUSTOMER_DB_PASSWORD',
          'name' => 'MYSQL_PASSWORD',
          'type' => 'env'
        }
        from = { 'secrets' => [secret] }
        to = {}
        result = described_class.new(to).extend(from)
        expect(result['secrets']).to eq([secret])
      end

      it 'overrides secrets' do
        from_secret = {
          'secret' => 'CUSTOMER_DB_PASSWORD',
          'name' => 'MYSQL_PASSWORD',
          'type' => 'env'
        }

        to_secret = {
          'secret' => 'CUSTOMER_DB_PASSWORD',
          'name' => 'MYSQL_ROOT_PASSWORD',
          'type' => 'env'
        }
        from = { 'secrets' => [from_secret] }
        to = { 'secrets' => [to_secret] }
        result = described_class.new(to).extend(from)
        expect(result['secrets']).to eq([to_secret])
      end

      it 'combines secrets' do
        from_secret = {
          'secret' => 'CUSTOMER_DB_PASSWORD',
          'name' => 'MYSQL_PASSWORD',
          'type' => 'env'
        }

        to_secret = {
          'secret' => 'CUSTOMER_API_TOKEN',
          'name' => 'API_TOKEN',
          'type' => 'env'
        }
        from = { 'secrets' => [from_secret] }
        to = { 'secrets' => [to_secret] }
        result = described_class.new(to).extend(from)
        expect(result['secrets']).to eq([to_secret, from_secret])
      end
    end

    context 'build args' do
      it 'inherits build args from upper level' do
        from = { 'build' => { 'args' => {'foo' => 'bar'}} }
        to = {}
        result = described_class.new(to).extend(from)
        expect(result['build']['args']).to eq({'foo' => 'bar'})
      end

      it 'overrides values' do
        from = { 'build' => { 'args' => {'foo' => 'bar'}} }
        to = { 'build' => { 'args' => {'foo' => 'baz'}} }
        result = described_class.new(to).extend(from)
        expect(result['build']['args']).to eq({'foo' => 'baz'})
      end

      it 'combines variables' do
        from = { 'build' => { 'args' => {'foo' => 'bar'}} }
        to = { 'build' => { 'args' => {'baz' => 'baf'}} }
        result = described_class.new(to).extend(from)
        expect(result['build']['args']).to eq({'foo' => 'bar', 'baz' => 'baf'})
      end
    end

  end
end

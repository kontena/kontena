require_relative '../../../../spec_helper'
require 'kontena/cli/stacks/yaml/reader'
require 'liquid'

describe Kontena::Cli::Stacks::YAML::Reader do
  include FixturesHelpers

  def absolute_yaml_path(file = 'kontena_v3.yml')
    "#{Dir.pwd}/#{file}"
  end

  let(:subject) do
    described_class.new('kontena_v3.yml')
  end

  let(:service_extender) do
    spy
  end

  let(:env_file) do
    ['APIKEY=12345
', 'MYSQL_ROOT_PASSWORD=secret
', 'WP_ADMIN_PASSWORD=verysecret']
  end

  let(:valid_v3_result) do
    {
      'stack' => 'user/stackname',
      'version' => '2',
      'services' => {
        'wordpress' => {
          'image' => 'wordpress:4.1',
          'ports' => ['80:80'],
          'depends_on' => ['mysql'],
          'stateful' => true,
          'environment' => ['WORDPRESS_DB_PASSWORD=test_secret'],
          'instances' => 2,
          'deploy' => { 'strategy' => 'ha' },
          'secrets' => []
        },
        'mysql' => {
          'image' => 'mysql:5.6',
          'stateful' => true,
          'environment' => ['MYSQL_ROOT_PASSWORD=test_secret'],
          'secrets' => []
        }
      }
    }
  end

  before(:each) do
    allow(File).to receive(:read)
      .with(absolute_yaml_path('docker-compose_v2.yml'))
      .and_return(fixture('docker-compose_v2.yml'))
    allow(File).to receive(:read)
      .with(absolute_yaml_path('kontena_v3.yml'))
      .and_return(fixture('kontena_v3.yml'))
    allow_any_instance_of(described_class).to receive(:env)
      .and_return( { 'STACK' => 'test', 'GRID' => 'test-grid' } )
  end

  describe '#initialize' do
    it 'reads given file' do
      expect(File).to receive(:read)
        .with(absolute_yaml_path)
        .and_return(fixture('kontena_v3.yml'))
      subject
    end
  end

  context 'when yaml file is malformed' do
    it 'exits the execution' do
      allow(File).to receive(:read)
        .with(absolute_yaml_path)
        .and_return(fixture('kontena-malformed-yaml.yml'))
      expect {
        subject.execute
      }.to raise_error(StandardError)
    end
  end

  context 'when service config is not hash' do
    it 'returns error' do
      allow(File).to receive(:read)
        .with(absolute_yaml_path)
        .and_return(fixture('kontena-not-hash-service-config.yml'))

      outcome = subject.execute
      expect(outcome[:errors].size).to eq(1)
    end
  end

  describe '#execute' do
    context 'when extending services' do
      it 'extends services from external file' do
        docker_compose_yml = YAML.load(fixture('docker-compose_v2.yml'))
        wordpress_options = {
          'extends' => {
            'file' => 'docker-compose_v2.yml',
            'service' => 'wordpress'
          },
          'stateful' => true,
          'environment' => ['WORDPRESS_DB_PASSWORD=test_secret'],
          'instances' => 2,
          'deploy' => { 'strategy' => 'ha' }
        }
        mysql_options = {
          'extends' => {
            'file' => 'docker-compose_v2.yml',
            'service' => 'mysql'
          },
          'stateful' => true,
          'environment' => ['MYSQL_ROOT_PASSWORD=test_secret']
        }
        expect(Kontena::Cli::Stacks::YAML::ServiceExtender).to receive(:new)
          .with(wordpress_options)
          .once
          .and_return(service_extender)
        expect(Kontena::Cli::Stacks::YAML::ServiceExtender).to receive(:new)
          .with(mysql_options)
          .once
          .and_return(service_extender)
        expect(service_extender).to receive(:extend_from).with(docker_compose_yml['services']['wordpress'])
        expect(service_extender).to receive(:extend_from).with(docker_compose_yml['services']['mysql'])

        subject.execute
      end

      it 'extends services from the same file' do
        expect(File).to receive(:read)
          .with(absolute_yaml_path('kontena_v3.yml'))
          .and_return(fixture('stack-internal-extend.yml'))
        kontena_yml = YAML.load(fixture('stack-internal-extend.yml'))

        expect(Kontena::Cli::Stacks::YAML::ServiceExtender).to receive(:new)
          .with(kontena_yml['services']['app'])
          .once
          .and_return(service_extender)
        expect(service_extender).to receive(:extend_from).with(kontena_yml['services']['base'])
        subject.execute
      end

      it 'merges validation errors' do
        allow(File).to receive(:read)
          .with(absolute_yaml_path('docker-compose_v2.yml'))
          .and_return(fixture('docker-compose-invalid.yml'))
        outcome = subject.execute
        expect(outcome[:errors]).to eq([{
          'docker-compose_v2.yml' =>[
            {
              'wordpress' => {
                'networks' => 'key not expected'
              }
            }
          ]
        }])
      end

    end

    context 'variable interpolation' do
      before(:each) do
        allow_any_instance_of(described_class).to receive(:env).and_return(
          {
            'STACK' => 'test',
            'GRID' => 'test-grid',
            'TAG' => '4.1'
          }
        )
        allow(ENV).to receive(:[]).with('TEST_ENV_VAR').and_return('foo')
        allow(ENV).to receive(:[]).with('MYSQL_IMAGE').and_return('mariadb:latest')
      end

      it 'interpolates $VAR variables' do
        allow(File).to receive(:read)
          .with(absolute_yaml_path)
          .and_return(fixture('stack-with-variables.yml'))
        result = subject.execute
        services = result[:services]
        expect(services['wordpress']['image']).to eq('wordpress:4.1')
      end

      it 'interpolates ${VAR} variables' do
        allow(File).to receive(:read)
          .with(absolute_yaml_path)
          .and_return(fixture('stack-with-variables.yml'))
        result = subject.execute
        services = result[:services]
        expect(services['mysql']['image']).to eq('mariadb:latest')
      end

      it 'warns about empty variables' do
        allow(File).to receive(:read)
          .with(absolute_yaml_path)
          .and_return(fixture('stack-with-variables.yml'))
        allow(ENV).to receive(:[])
          .with('MYSQL_IMAGE')
          .and_return('')
        allow(ENV).to receive(:[])
          .with('TAG')
          .and_return('4.1')

        expect {
          subject.execute
        }.to output("Value for MYSQL_IMAGE is not set. Substituting with an empty string.\n").to_stdout
      end
    end

    it 'replaces $$VAR variables to $VAR format' do
      allow_any_instance_of(described_class).to receive(:env).and_return(
        {
          'STACK' => 'test',
          'GRID' => 'test-grid'
        }
      )
      allow(ENV).to receive(:[]).with('TAG').and_return('4.1')
      allow(ENV).to receive(:[]).with('TEST_ENV_VAR').and_return('foo')
      allow(ENV).to receive(:[]).with('MYSQL_IMAGE').and_return('foo')
      allow(File).to receive(:read)
        .with(absolute_yaml_path)
        .and_return(fixture('stack-with-variables.yml'))
      allow(File).to receive(:read)
        .with(absolute_yaml_path('docker-compose_v2.yml'))
        .and_return(fixture('docker-compose_v2.yml'))
      services = subject.execute[:services]
      expect(services['mysql']['environment'].first).to eq('INTERNAL_VAR=$INTERNAL_VAR')
    end

    context 'environment variables' do
      it 'converts env hash to array' do
        result = subject.execute[:services]
        expect(result['wordpress']['environment']).to eq(['WORDPRESS_DB_PASSWORD=test_secret'])
      end

      it 'does nothing to env array' do
        result = subject.execute[:services]
        expect(result['mysql']['environment']).to eq(['MYSQL_ROOT_PASSWORD=test_secret'])
      end

      context 'when introduced env_file' do
        before(:each) do
          allow(File).to receive(:read)
            .with(absolute_yaml_path('kontena_v3.yml'))
            .and_return(fixture('stack-with-env-file.yml'))
          allow(File).to receive(:readlines).with('.env').and_return(env_file)
        end

        it 'reads given file' do
          expect(File).to receive(:readlines).with('.env').and_return(env_file)
          subject.send(:read_env_file, '.env')
        end

        it 'discards comment lines' do
          result = env_file
          result << "#COMMENTLINE"
          allow(File).to receive(:readlines).with('.env').and_return(result)

          variables = subject.send(:read_env_file, '.env')
          expect(variables).to eq([
            'APIKEY=12345',
            'MYSQL_ROOT_PASSWORD=secret',
            'WP_ADMIN_PASSWORD=verysecret'
            ])
        end

        it 'discards empty lines' do
          result = env_file
          result << '
    '
          allow(File).to receive(:readlines).with('.env').and_return(result)
          variables = subject.send(:read_env_file, '.env')
          expect(variables).to eq([
            'APIKEY=12345',
            'MYSQL_ROOT_PASSWORD=secret',
            'WP_ADMIN_PASSWORD=verysecret'
            ])
        end

        it 'merges variables' do
          result = subject.execute[:services]
          expect(result['wordpress']['environment']).to eq([
            'WORDPRESS_DB_PASSWORD=test_secret',
            'APIKEY=12345',
            'MYSQL_ROOT_PASSWORD=secret',
            'WP_ADMIN_PASSWORD=verysecret'
            ])
        end

      end
    end

    it 'returns result hash' do
      outcome = subject.execute
      expect(outcome[:services]).to eq(valid_v3_result['services'])
    end

    it 'returns validation errors' do
      allow(File).to receive(:read)
        .with(absolute_yaml_path('kontena_v3.yml'))
        .and_return(fixture('stack-invalid.yml'))
      outcome = subject.execute
      expect(outcome[:errors].size).to eq(1)
    end
  end

  context 'when build option is string' do
    it 'expands build option to absolute path' do
      allow(File).to receive(:read)
        .with(absolute_yaml_path)
        .and_return(fixture('kontena_build_v3.yml'))
      outcome = subject.execute
      expect(outcome[:services]['webapp']['build']['context']).to eq(File.expand_path('.'))
    end
  end

  context 'when build option is Hash' do
    it 'expands build context to absolute path' do
      allow(File).to receive(:read)
        .with(absolute_yaml_path)
        .and_return(fixture('kontena_build_v3.yml'))
      outcome = subject.execute
      expect(outcome[:services]['webapp']['build']['context']).to eq(File.expand_path('.'))
    end
  end

  context 'normalize_build_args' do
    context 'when build option is string' do
      it 'skips normalizing' do
        allow(File).to receive(:read)
          .with(absolute_yaml_path)
          .and_return(fixture('kontena_build_v3.yml'))

        options = {
          'build' => '.'
        }
        expect {
          subject.send(:normalize_build_args, options)
        }.not_to raise_error
      end
    end

    context 'when build arguments option is Hash' do
      it 'does not do anything' do
        allow(File).to receive(:read)
          .with(absolute_yaml_path)
          .and_return(fixture('kontena_build_v3.yml'))

        options = {
          'build' => {
            'context' => '.',
            'args' => {
              'foo' => 'bar'
            }
          }
        }

        subject.send(:normalize_build_args, options)
        expect(options.dig('build', 'args')).to eq({
          'foo' => 'bar'
        })
      end
    end

    context 'when build arguments option is Array' do
      it 'converts it to array' do
        allow(File).to receive(:read)
          .with(absolute_yaml_path)
          .and_return(fixture('kontena_build_v3.yml'))

        options = {
          'build' => {
            'context' => '.',
            'args' => ['foo=bar']
          }
        }

        subject.send(:normalize_build_args, options)
        expect(options.dig('build', 'args')).to eq({
          'foo' => 'bar'
        })
      end
    end
  end

  describe '#stack_name' do
    it 'returns name for v3' do
      allow(File).to receive(:read)
        .with(absolute_yaml_path)
        .and_return(fixture('kontena_v3.yml'))
      name = subject.stack_name
      expect(name).to eq('stackname')
    end
  end

  context 'origins' do
    it 'can read from a file' do
      expect(File).to receive(:read)
        .with(absolute_yaml_path('kontena_v3.yml'))
        .and_return(fixture('stack-with-liquid.yml'))
      expect(subject.from_file?).to be_truthy
    end

    it 'can read from the registry' do
      expect(Kontena::StacksCache).to receive(:pull)
        .with('foo/foo')
        .and_return(fixture('stack-with-liquid.yml'))
      expect(Kontena::StacksCache).to receive(:registry_url).and_return('foo')
      expect(described_class.new('foo/foo').from_registry?).to be_truthy
    end

    it 'can read from an url' do
     stub_request(:get, "http://foo.example.com/foo").to_return(:status => 200, :body => fixture('stack-with-liquid.yml'), :headers => {})
      expect(described_class.new('http://foo.example.com/foo').from_url?).to be_truthy
    end
  end

  context 'liquid' do
    context 'valid' do
      before(:each) do
        allow(File).to receive(:read)
          .with(absolute_yaml_path('kontena_v3.yml'))
          .and_return(fixture('stack-with-liquid.yml'))
        allow_any_instance_of(described_class).to receive(:env).and_return(
          {
            'STACK' => 'test',
            'GRID' => 'test-grid',
            'TAG' => '4.1',
            'MYSQL_IMAGE' => 'mariadb:latest'
          }
        )
        allow(ENV).to receive(:[]).with('TEST_ENV_VAR').and_return('foo')
      end

      it 'does not interpolate liquid into variables' do
        expect(subject.variables.value_of('grid_name')).to eq '{{ GRID }} test'
      end

      it 'interpolates variables into services' do
        expect(subject.execute[:services].size).to eq 5
      end
    end

    context 'invalid' do
      before(:each) do
        allow(File).to receive(:read)
          .with(absolute_yaml_path('kontena_v3.yml'))
          .and_return(fixture('stack-with-invalid-liquid.yml'))
        allow_any_instance_of(described_class).to receive(:env).and_return(
          {
            'STACK' => 'test',
            'GRID' => 'test-grid',
            'TAG' => '4.1',
            'MYSQL_IMAGE' => 'mariadb:latest'
          }
        )
        allow(ENV).to receive(:[]).with('TEST_ENV_VAR').and_return('foo')
      end

      it 'raises' do
        expect{subject.execute}.to raise_error(Liquid::SyntaxError)
      end
    end
  end
end

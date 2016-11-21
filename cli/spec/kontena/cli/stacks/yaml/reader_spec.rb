require_relative '../../../../spec_helper'
require 'kontena/cli/stacks/yaml/reader'

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
          'extends' => {"file"=>"docker-compose_v2.yml", "service"=>"wordpress"},
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
          'extends' => {"file"=>"docker-compose_v2.yml", "service"=>"mysql"},
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
  end

  describe '#initialize' do
    it 'reads given file' do
      expect(File).to receive(:read)
        .with(absolute_yaml_path)
        .and_return(fixture('kontena_v3.yml'))
      subject
    end

    context 'variable interpolation' do
      before(:each) do
        allow(ENV).to receive(:key?).and_return(true)
        allow(ENV).to receive(:[]).with('TAG').and_return('4.1')
        allow(ENV).to receive(:[]).with('STACK').and_return('test')
        allow(ENV).to receive(:[]).with('grid').and_return('test-grid')
        allow(ENV).to receive(:[]).with('MYSQL_IMAGE').and_return('mariadb:latest')
      end

      it 'interpolates $VAR variables' do
        allow(File).to receive(:read)
          .with(absolute_yaml_path)
          .and_return(fixture('stack-with-variables.yml'))
        services = subject.yaml['services']
        expect(services['wordpress']['image']).to eq('wordpress:4.1')
      end

      it 'interpolates ${VAR} variables' do
        allow(File).to receive(:read)
          .with(absolute_yaml_path)
          .and_return(fixture('stack-with-variables.yml'))
        services = subject.yaml['services']
        expect(services['mysql']['image']).to eq('mariadb:latest')
      end

      it 'warns about empty variables' do
        allow(File).to receive(:read)
          .with(absolute_yaml_path)
          .and_return(fixture('stack-with-variables.yml'))
        allow(ENV).to receive(:key?)
          .with('MYSQL_IMAGE')
          .and_return(false)

        expect {
          subject
        }.to output('The MYSQL_IMAGE is not set. Substituting an empty string.
').to_stdout
      end
    end

    it 'replaces $$VAR variables to $VAR format' do
      allow(ENV).to receive(:key?).and_return(true)
      allow(ENV).to receive(:[]).with('TAG').and_return('4.1')
      allow(ENV).to receive(:[]).with('MYSQL_IMAGE').and_return('mariadb:latest')
      allow(ENV).to receive(:[]).with('STACK').and_return('test')
      allow(ENV).to receive(:[]).with('grid').and_return('test-grid')
      allow(File).to receive(:read)
        .with(absolute_yaml_path)
        .and_return(fixture('stack-with-variables.yml'))
      allow(File).to receive(:read)
        .with(absolute_yaml_path('docker-compose_v2.yml'))
        .and_return(fixture('docker-compose_v2.yml'))
      services = subject.execute[:services]
      expect(services['mysql']['environment'].first).to eq('INTERNAL_VAR=$INTERNAL_VAR')
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
    before(:each) do
      allow(ENV).to receive(:[]).with('STACK').and_return('test')
      allow(ENV).to receive(:[]).with('grid').and_return('test-grid')
    end

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
        allow(File).to receive(:read)
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
        .and_return(fixture('kontena-invalid.yml'))
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
      puts outcome
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
end

require 'kontena/cli/grid_options'
require "kontena/cli/apps/deploy_command"

describe Kontena::Cli::Apps::DeployCommand do
  include FixturesHelpers
  include ClientHelpers

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:docker_compose_yml) do
    fixture('docker-compose.yml')
  end

  let(:kontena_yml) do
    fixture('kontena.yml')
  end

  let(:services) do
    {
        'wordpress' => {
            'image' => 'wordpress:latest',
            'links' => ['mysql:db'],
            'ports' => ['80:80'],
            'instances' => 2,
            'deploy' => {
                'strategy' => 'ha'
            }
        },
        'mysql' => {
            'image' => 'mysql:5.6',
            'stateful' => true
        }
    }
  end

  let(:options) do
    double({prefix: false, file: false, service: nil})
  end

  let(:env_vars) do
    ["#comment line", "TEST_ENV_VAR=test", "MYSQL_ADMIN_PASSWORD=abcdef"]
  end

  let(:dot_env) do
    ["TEST_ENV_VAR=test2","", "TEST_ENV_VAR2=test3"]
  end

  describe '.run' do

    before(:each) do
      allow(subject).to receive(:wait_for_deploy_to_finish).and_return(true)
    end

    context 'when api_url is nil' do
      it 'raises error' do
        allow(subject.config).to receive(:current_master).and_return(
          Kontena::Cli::Config::Server.new
        )
        expect{subject.run([])}.to exit_with_error
      end
    end

    context 'when token is nil' do
      it 'raises error' do
        allow(subject.config).to receive(:current_master).and_return(
          Kontena::Cli::Config::Server.new(url: 'http://foo.com')
        )
        expect{subject.run([])}.to exit_with_error
      end
    end

    context 'when api url and token are valid' do
      before(:each) do
        allow(File).to receive(:exists?).and_return(true)
        allow(File).to receive(:read).with("#{Dir.getwd}/kontena.yml").and_return(kontena_yml)
        allow(File).to receive(:read).with("#{Dir.getwd}/docker-compose.yml").and_return(docker_compose_yml)
        allow(subject).to receive(:get_service).and_raise(Kontena::Errors::StandardError.new(404, 'Not Found'))
        allow(subject).to receive(:create_service).and_return({'id' => 'cli/kontena-test-mysql', 'name' => 'kontena-test-mysql'},{'id' => 'cli/kontena-test-wordpress', 'name' => 'kontena-test-wordpress'})
        allow(subject).to receive(:current_grid).and_return('1')
        allow(subject).to receive(:deploy_service).and_return(nil)
      end

      it 'reads ./kontena.yml file by default' do
        expect(File).to receive(:read).with("#{Dir.getwd}/kontena.yml").and_return(kontena_yml)
        subject.run([])
      end

      it 'reads given yml file' do
        allow(subject).to receive(:project_name_from_yaml).and_return nil
        expect(File).to receive(:read).with("#{Dir.getwd}/custom.yml").and_return(kontena_yml)
        subject.run(["--file", "custom.yml"])
      end

      it 'uses current directory as service name prefix by default' do
        current_dir = '/kontena/tests/stacks'
        allow(Dir).to receive(:getwd).and_return(current_dir)
        expect(File).to receive(:basename).with(current_dir).and_return('stacks')
        subject.run([])
      end

      context 'when yml file has multiple env files' do
        it 'merges environment variables correctly' do
          allow(subject).to receive(:current_dir).and_return("kontena-test")
          services['wordpress']['environment'] = ['MYSQL_ADMIN_PASSWORD=password']
          services['wordpress']['env_file'] = %w(/path/to/env_file .env)
          allow(YAML).to receive(:safe_load).and_return(services)

          expect(File).to receive(:readlines).with('/path/to/env_file').and_return(env_vars)
          expect(File).to receive(:readlines).with('.env').and_return(dot_env)

          data = {
              'name' => 'kontena-test-wordpress',
              'image' => 'wordpress:latest',
              'env' => ['MYSQL_ADMIN_PASSWORD=password', 'TEST_ENV_VAR=test', 'TEST_ENV_VAR2=test3'],
          }

          expect(subject).to receive(:create_service).with(duck_type(:access_token), '1', hash_including(data))
          subject.run([])
        end
      end

      context 'when yml file has one env file' do
        it 'merges environment variables correctly' do
          allow(subject).to receive(:current_dir).and_return("kontena-test")
          services['wordpress']['environment'] = ['MYSQL_ADMIN_PASSWORD=password']
          services['wordpress']['env_file'] = '/path/to/env_file'
          allow(YAML).to receive(:safe_load).and_return(services)

          expect(File).to receive(:readlines).with('/path/to/env_file').and_return(env_vars)

          data = {
              'name' => 'kontena-test-wordpress',
              'image' => 'wordpress:latest',
              'env' => ['MYSQL_ADMIN_PASSWORD=password', 'TEST_ENV_VAR=test']
          }

          expect(subject).to receive(:create_service).with(duck_type(:access_token), '1', hash_including(data))
          subject.run([])
        end
      end

      it 'merges external links to links' do
        allow(subject).to receive(:current_dir).and_return("kontena-test")
        services['wordpress']['external_links'] = ['loadbalancer:loadbalancer']
        allow(YAML).to receive(:safe_load).and_return(services)
        data = {
          'name' => 'kontena-test-wordpress',
          'image' => 'wordpress:latest',
          'links' => [
            {
              'name' => 'kontena-test-mysql',
              'alias' => 'db'
            },
            {
              'name' => 'loadbalancer',
              'alias' => 'loadbalancer'
            }
          ]
        }

        expect(subject).to receive(:create_service).with(duck_type(:access_token), '1', hash_including(data))
        subject.run([])
      end

      it 'creates mysql service before wordpress' do
        allow(subject).to receive(:current_dir).and_return("kontena-test")
        data = {
            'name' => 'kontena-test-mysql',
            'image' => 'mysql:5.6',
            'env' => ['MYSQL_ROOT_PASSWORD=kontena-test_secret'],
            'instances' => nil,
            'stateful' => true,
        }
        expect(subject).to receive(:create_service).with(duck_type(:access_token), '1', hash_including(data))

        subject.run([])
      end

      it 'creates wordpress service' do
        allow(subject).to receive(:current_dir).and_return('kontena-test')

        data = {
          'name' => 'kontena-test-wordpress',
          'image' => 'wordpress:4.1',
          'env' => ['WORDPRESS_DB_PASSWORD=kontena-test_secret'],
          'instances' => 2,
          'stateful' => true,
          'strategy' => 'ha',
          'links' => [{ 'name' => 'kontena-test-mysql', 'alias' => 'mysql' }],
          'ports' => [{ 'ip' => '0.0.0.0','container_port' => '80', 'node_port' => '80', 'protocol' => 'tcp' }]
        }
        expect(subject).to receive(:create_service).with(duck_type(:access_token), '1', hash_including(data))

        subject.run([])
      end

      it 'deploys services' do
        allow(subject).to receive(:current_dir).and_return('kontena-test')
        expect(subject).to receive(:deploy_service).with(duck_type(:access_token), 'kontena-test-mysql', {})
        expect(subject).to receive(:deploy_service).with(duck_type(:access_token), 'kontena-test-wordpress', {})
        subject.run([])
      end

      context 'when giving service option' do
        it 'deploys only given services' do
          allow(subject).to receive(:current_dir).and_return("kontena-test")
          allow(subject).to receive(:deploy_services).and_return({})
          expect(subject).to receive(:create).once.with('wordpress', anything).and_return({})
          expect(subject).not_to receive(:create).with('mysql', services['mysql'])

          subject.run(['wordpress'])
        end
      end
    end
  end
end

require_relative "../../../spec_helper"
require "kontena/cli/apps/deploy_command"

describe Kontena::Cli::Apps::DeployCommand do

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:settings) do
    {'current_server' => 'alias',
     'servers' => [
         {'name' => 'some_master', 'url' => 'some_master'},
         {'name' => 'alias', 'url' => 'someurl', 'token' => token}
     ]
    }
  end

  let(:settings_without_api_url) do
    {'current_server' => 'alias',
     'servers' => [
         {'name' => 'alias', 'token' => token}
     ]
    }
  end

  let(:settings_without_token) do
    {'current_server' => 'alias',
     'servers' => [
         {'name' => 'alias', 'url' => 'url'}
     ]
    }
  end

  let(:token) do
    '1234567'
  end

  let(:docker_compose_yml) do
    yml_content = <<yml
wordpress:
  image: wordpress:4.1
  ports:
    - 80:80
  links:
    - mysql:mysql
mysql:
  image: mysql:5.6
yml
    yml_content
  end

  let(:kontena_yml) do
    yml_content = <<yml
wordpress:
  extends:
    file: docker-compose.yml
    service: wordpress
  stateful: true
  environment:
    - WORDPRESS_DB_PASSWORD=%{project}_secret
  instances: 2
  deploy:
    strategy: ha
mysql:
  extends:
    file: docker-compose.yml
    service: mysql
  stateful: true
  environment:
    - MYSQL_ROOT_PASSWORD=%{project}_secret
yml
    yml_content
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

  let(:client) do
    double
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
        allow(subject).to receive(:settings).and_return(settings_without_api_url)
        expect{subject.run([])}.to raise_error(ArgumentError)
      end
    end

    context 'when token is nil' do
      it 'raises error' do
        allow(subject).to receive(:settings).and_return(settings_without_token)
        expect{subject.run([])}.to raise_error(ArgumentError)
      end
    end

    context 'when api url and token are valid' do
      before(:each) do
        allow(subject).to receive(:settings).and_return(settings)
        allow(File).to receive(:exists?).and_return(true)
        allow(File).to receive(:read).with("#{Dir.getwd}/kontena.yml").and_return(kontena_yml)
        allow(File).to receive(:read).with("#{Dir.getwd}/docker-compose.yml").and_return(docker_compose_yml)
        allow(subject).to receive(:get_service).and_raise(Kontena::Errors::StandardError.new(404, 'Not Found'))
        allow(subject).to receive(:create_service).and_return({'id' => 'cli/kontena-test-mysql', 'name' => 'kontena-test-mysql'},{'id' => 'cli/kontena-test-wordpress', 'name' => 'kontena-test-wordpress'})
        allow(subject).to receive(:current_grid).and_return('1')
        allow(subject).to receive(:deploy_service).and_return(nil)
      end

      it 'reads ./kontena.yml file by default' do
        allow(subject).to receive(:settings).and_return(settings)
        expect(File).to receive(:read).with("#{Dir.getwd}/kontena.yml").and_return(kontena_yml)
        subject.run([])
      end

      it 'reads given yml file' do
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
          allow(YAML).to receive(:load).and_return(services)
          services['wordpress']['environment'] = ['MYSQL_ADMIN_PASSWORD=password']
          services['wordpress']['env_file'] = %w(/path/to/env_file .env)

          expect(File).to receive(:readlines).with('/path/to/env_file').and_return(env_vars)
          expect(File).to receive(:readlines).with('.env').and_return(dot_env)

          data = {
              :name =>"kontena-test-wordpress",
              :image=>"wordpress:latest",
              :env=>["MYSQL_ADMIN_PASSWORD=password", "TEST_ENV_VAR=test", "TEST_ENV_VAR2=test3"],
              :container_count=>2,
              :stateful=>false,
              :strategy=>'ha',
              :links=>[{:name=>"kontena-test-mysql", :alias=>"db"}],
              :ports=>[{:container_port=>"80", :node_port=>"80", :protocol=>"tcp"}]
          }

          expect(subject).to receive(:create_service).with('1234567', '1', hash_including(data))
          subject.run([])
        end
      end

      context 'when yml file has one env file' do
        it 'merges environment variables correctly' do
          allow(subject).to receive(:current_dir).and_return("kontena-test")
          allow(YAML).to receive(:load).and_return(services)
          services['wordpress']['environment'] = ['MYSQL_ADMIN_PASSWORD=password']
          services['wordpress']['env_file'] = '/path/to/env_file'

          expect(File).to receive(:readlines).with('/path/to/env_file').and_return(env_vars)

          data = {
              :name =>"kontena-test-wordpress",
              :image=>"wordpress:latest",
              :env=>["MYSQL_ADMIN_PASSWORD=password", "TEST_ENV_VAR=test"],
              :container_count=>2,
              :stateful=>false,
              :strategy=>'ha',
              :links=>[{:name=>"kontena-test-mysql", :alias=>"db"}],
              :ports=>[{:container_port=>"80", :node_port=>"80", :protocol=>"tcp"}]
          }

          expect(subject).to receive(:create_service).with('1234567', '1', hash_including(data))
          subject.run([])
        end
      end

      it 'merges external links to links' do
        allow(subject).to receive(:current_dir).and_return("kontena-test")
        allow(YAML).to receive(:load).and_return(services)
        services['wordpress']['external_links'] = ['loadbalancer:loadbalancer']
        data = {
            :name =>"kontena-test-wordpress",
            :image=>"wordpress:latest",
            :env=> nil,
            :container_count=>2,
            :stateful=>false,
            :strategy=>'ha',
            :links=>[{:name => "kontena-test-mysql", :alias => "db"}, {:name => "loadbalancer", :alias => "loadbalancer"}],
            :ports=>[{:container_port => "80", :node_port => "80", :protocol => "tcp"}]
        }

        expect(subject).to receive(:create_service).with('1234567', '1', hash_including(data))
        subject.run([])
      end

      it 'creates mysql service before wordpress' do
        allow(subject).to receive(:current_dir).and_return("kontena-test")
        data = {
            :name =>"kontena-test-mysql",
            :image=>'mysql:5.6',
            :env=>["MYSQL_ROOT_PASSWORD=kontena-test_secret"],
            :container_count=>nil,
            :stateful=>true,
        }
        expect(subject).to receive(:create_service).with('1234567', '1', hash_including(data))

        subject.run([])
      end

      it 'creates wordpress service' do
        allow(subject).to receive(:current_dir).and_return("kontena-test")

        data = {
            :name =>"kontena-test-wordpress",
            :image=>"wordpress:4.1",
            :env=>["WORDPRESS_DB_PASSWORD=kontena-test_secret"],
            :container_count=>2,
            :stateful=>true,
            :strategy=>'ha',
            :links=>[{:name=>"kontena-test-mysql", :alias=>"mysql"}],
            :ports=>[{:container_port=>"80", :node_port=>"80", :protocol=>"tcp"}]
        }
        expect(subject).to receive(:create_service).with('1234567', '1', hash_including(data))

        subject.run([])
      end

      it 'deploys services' do
        allow(subject).to receive(:current_dir).and_return("kontena-test")
        expect(subject).to receive(:deploy_service).with('1234567', 'kontena-test-mysql', {})
        expect(subject).to receive(:deploy_service).with('1234567', 'kontena-test-wordpress', {})
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

  describe '#parse_data' do

    context 'volumes' do
      it 'returns volumes if set' do
        data = {
          'image' => 'foo/bar:latest',
          'volumes' => [
            'mongodb-1'
          ]
        }
        result = subject.send(:parse_data, data)
        expect(result[:volumes]).to eq(data['volumes'])
      end

      it 'returns empty volumes if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result[:volumes]).to eq([])
      end
    end

    context 'volumes_from' do
      it 'returns volumes_from if set' do
        data = {
          'image' => 'foo/bar:latest',
          'volumes_from' => [
            'mongodb-1'
          ]
        }
        result = subject.send(:parse_data, data)
        expect(result[:volumes_from]).to eq(data['volumes_from'])
      end

      it 'returns empty volumes_from if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result[:volumes_from]).to eq([])
      end
    end

    context 'command' do
      it 'returns cmd array if set' do
        data = {
          'image' => 'foo/bar:latest',
          'command' => 'ls -la'
        }
        result = subject.send(:parse_data, data)
        expect(result[:cmd]).to eq(data['command'].split(' '))
      end

      it 'does not return cmd if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result.has_key?(:cmd)).to be_falsey
      end
    end

    context 'affinity' do
      it 'returns affinity if set' do
        data = {
          'image' => 'foo/bar:latest',
          'affinity' => [
            'label==az=b'
          ]
        }
        result = subject.send(:parse_data, data)
        expect(result[:affinity]).to eq(data['affinity'])
      end

      it 'returns affinity as empty array if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result.has_key?(:affinity)).to be_truthy
        expect(result[:affinity]).to eq([])
      end
    end

    context 'user' do
      it 'returns user if set' do
        data = {
          'image' => 'foo/bar:latest',
          'user' => 'user'
        }
        result = subject.send(:parse_data, data)
        expect(result[:user]).to eq('user')
      end

      it 'does not return user if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result.has_key?(:user)).to be_falsey
      end
    end

    context 'stateful' do
      it 'returns stateful if set' do
        data = {
          'image' => 'foo/bar:latest',
          'stateful' => true
        }
        result = subject.send(:parse_data, data)
        expect(result[:stateful]).to eq(true)
      end

      it 'returns stateful as false if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result[:stateful]).to eq(false)
      end
    end

    context 'privileged' do
      it 'returns privileged if set' do
        data = {
          'image' => 'foo/bar:latest',
          'privileged' => false
        }
        result = subject.send(:parse_data, data)
        expect(result[:privileged]).to eq(false)
      end

      it 'does not return privileged if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result[:privileged]).to be_nil
      end
    end

    context 'cap_add' do
      it 'returns cap_drop if set' do
        data = {
          'image' => 'foo/bar:latest',
          'cap_add' => [
            'NET_ADMIN'
          ]
        }
        result = subject.send(:parse_data, data)
        expect(result[:cap_add]).to eq(data['cap_add'])
      end

      it 'does not return cap_add if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result[:cap_add]).to be_nil
      end
    end

    context 'cap_drop' do
      it 'returns cap_drop if set' do
        data = {
          'image' => 'foo/bar:latest',
          'cap_drop' => [
            'NET_ADMIN'
          ]
        }
        result = subject.send(:parse_data, data)
        expect(result[:cap_drop]).to eq(data['cap_drop'])
      end

      it 'does not return cap_drop if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result[:cap_drop]).to be_nil
      end
    end

    context 'net' do
      it 'returns net if set' do
        data = {
          'image' => 'foo/bar:latest',
          'net' => 'host'
        }
        result = subject.send(:parse_data, data)
        expect(result[:net]).to eq('host')
      end

      it 'does not return pid if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result[:net]).to be_nil
      end
    end

    context 'pid' do
      it 'returns pid if set' do
        data = {
          'image' => 'foo/bar:latest',
          'pid' => 'host'
        }
        result = subject.send(:parse_data, data)
        expect(result[:pid]).to eq('host')
      end

      it 'does not return pid if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result[:pid]).to be_nil
      end
    end

    context 'log_driver' do
      it 'returns log_driver if set' do
        data = {
          'image' => 'foo/bar:latest',
          'log_driver' => 'syslog'
        }
        result = subject.send(:parse_data, data)
        expect(result[:log_driver]).to eq('syslog')
      end

      it 'does not return log_driver if not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result[:log_driver]).to be_nil
      end
    end

    context 'log_opt' do
      it 'returns log_opts hash if log_opt is set' do
        data = {
          'image' => 'foo/bar:latest',
          'log_driver' => 'fluentd',
          'log_opt' => {
            'fluentd-address' => '192.168.99.1:24224',
            'fluentd-tag' => 'docker.{{.Name}}'
          }
        }
        result = subject.send(:parse_data, data)
        expect(result[:log_opts]).to eq(data['log_opt'])
      end

      it 'does not return log_opts if log_opt is not set' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result[:log_opts]).to be_nil
      end
    end

    context 'deploy_opts' do
      it 'returns deploy_opts if deploy.wait_for_port is defined' do
        data = {
          'image' => 'foo/bar:latest',
          'deploy' => {
            'wait_for_port' => '8080'
          }
        }
        result = subject.send(:parse_data, data)
        expect(result[:deploy_opts][:wait_for_port]).to eq('8080')
      end

      it 'returns deploy_opts if deploy.min_health is defined' do
        data = {
          'image' => 'foo/bar:latest',
          'deploy' => {
            'min_health' => '0.5'
          }
        }
        result = subject.send(:parse_data, data)
        expect(result[:deploy_opts][:min_health]).to eq('0.5')
      end

      it 'sets strategy if deploy.strategy is defined' do
        data = {
          'image' => 'foo/bar:latest',
          'deploy' => {
            'strategy' => 'daemon'
          }
        }
        result = subject.send(:parse_data, data)
        expect(result[:strategy]).to eq('daemon')
      end

      it 'does not return deploy_opts if no deploy options are defined' do
        data = {
          'image' => 'foo/bar:latest'
        }
        result = subject.send(:parse_data, data)
        expect(result[:deploy_opts]).to be_nil
      end
    end

    context 'hooks' do
      it 'returns hooks hash if defined' do
        data = {
          'image' => 'foo/bar:latest',
          'hooks' => {
            'post_start' => []
          }
        }
        result = subject.send(:parse_data, data)
        expect(result[:hooks]).to eq(data['hooks'])
      end

      it 'does returns empty hook hash if not defined' do
        data = {'image' => 'foo/bar:latest'}
        result = subject.send(:parse_data, data)
        expect(result[:hooks]).to eq({})
      end
    end

    context 'secrets' do
      it 'returns secrets array if defined' do
        data = {
          'image' => 'foo/bar:latest',
          'secrets' => [
            {'secret' => 'MYSQL_ADMIN_PASSWORD', 'name' =>  'WORDPRESS_DB_PASSWORD', 'type' => 'env'}
          ]
        }
        result = subject.send(:parse_data, data)
        expect(result[:secrets]).to eq(data['secrets'])
      end

      it 'does not return secrets if not defined' do
        data = {'image' => 'foo/bar:latest'}
        result = subject.send(:parse_data, data)
        expect(result[:secrets]).to be_nil
      end
    end
  end
end

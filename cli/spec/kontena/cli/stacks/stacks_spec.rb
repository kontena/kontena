require_relative "../../../spec_helper"
require "kontena/cli/stacks/stacks"

module Kontena::Cli::Stacks
  describe Stacks do
    let(:settings) do
      {'server' => {'url' => 'http://kontena.test', 'token' => token}}
    end

    let(:token) do
      '1234567'
    end

    let(:yml) do
      content = <<content
wordpress:
  image: wordpress:4.1
  stateful: true
  ports:
    - 80:80
  links:
    - mysql:mysql
  environment:
    - WORDPRESS_DB_PASSWORD=%{prefix}_secret
  instances: 2
  deploy:
    strategy: ha
mysql:
  image: mysql:5.6
  stateful: true
  environment:
    - MYSQL_ROOT_PASSWORD=%{prefix}_secret
content
      content
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
      options = double({prefix: false, file: false, service: nil})
    end

    let(:env_vars) do
      ["#comment line", "TEST_ENV_VAR=test", "MYSQL_ADMIN_PASSWORD=abcdef"]
    end

    let(:dot_env) do
      ["TEST_ENV_VAR=test2","", "TEST_ENV_VAR2=test3"]
    end

    describe '#deploy' do
      context 'when api_url is nil' do
        it 'raises error' do
          allow(subject).to receive(:settings).and_return({'server' => {}})
          expect{subject.deploy({})}.to raise_error(ArgumentError)
        end
      end

      context 'when token is nil' do
        it 'raises error' do
          allow(subject).to receive(:settings).and_return({'server' => {'url' => 'http://kontena.test'}})
          expect{subject.deploy({})}.to raise_error(ArgumentError)
        end
      end

      context 'when api url and token are valid' do
        before(:each) do
          allow(subject).to receive(:settings).and_return(settings)
          allow(File).to receive(:read).and_return(yml)
          allow(subject).to receive(:get_service).and_raise(Kontena::Errors::StandardError.new(404, 'Not Found'))
          allow(subject).to receive(:create_service).and_return({'id' => 'kontena-test-mysql'},{'id' => 'kontena-test-wordpress'})
          allow(subject).to receive(:current_grid).and_return('1')
          allow(subject).to receive(:deploy_service).and_return(nil)
        end

        it 'reads ./kontena.yml file by default' do
          allow(subject).to receive(:settings).and_return(settings)
          expect(File).to receive(:read).with('./kontena.yml').and_return(yml)
          expect(options).to receive(:file).once.and_return(false)
          subject.deploy(options)
        end

        it 'reads given yml file' do
          expect(options).to receive(:file).once.and_return('custom.yml')
          expect(File).to receive(:read).with('custom.yml').and_return(yml)
          subject.deploy(options)
        end

        it 'uses current directory as service name prefix by default' do
          current_dir = '/kontena/tests/stacks'
          allow(Dir).to receive(:getwd).and_return(current_dir)
          expect(File).to receive(:basename).with(current_dir).and_return('stacks')
          subject.deploy(options)
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
                :links=>[{:name=>"kontena-test-mysql", :alias=>"db"}],
                :ports=>[{:container_port=>"80", :node_port=>"80", :protocol=>"tcp"}]
            }

            expect(subject).to receive(:create_service).with('1234567', '1', data)
            subject.deploy(options)
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
                :links=>[{:name=>"kontena-test-mysql", :alias=>"db"}],
                :ports=>[{:container_port=>"80", :node_port=>"80", :protocol=>"tcp"}]
            }

            expect(subject).to receive(:create_service).with('1234567', '1', data)
            subject.deploy(options)
          end
        end

        it 'creates mysql service before wordpress' do
          allow(subject).to receive(:current_dir).and_return("kontena-test")
          data = {:name =>"kontena-test-mysql", :image=>'mysql:5.6', :env=>["MYSQL_ROOT_PASSWORD=kontena-test_secret"], :container_count=>nil, :stateful=>true}
          expect(subject).to receive(:create_service).with('1234567', '1', data)

          subject.deploy(options)
        end

        it 'creates wordpress service' do
          allow(subject).to receive(:current_dir).and_return("kontena-test")

          data = {
              :name =>"kontena-test-wordpress",
              :image=>"wordpress:4.1",
              :env=>["WORDPRESS_DB_PASSWORD=kontena-test_secret"],
              :container_count=>2,
              :stateful=>true,
              :links=>[{:name=>"kontena-test-mysql", :alias=>"mysql"}],
              :ports=>[{:container_port=>"80", :node_port=>"80", :protocol=>"tcp"}]
          }
          expect(subject).to receive(:create_service).with('1234567', '1', data)

          subject.deploy(options)
        end

        it 'deploys services' do
          allow(subject).to receive(:current_dir).and_return("kontena-test")
          expect(subject).to receive(:deploy_service).with('1234567', 'kontena-test-mysql', {})
          expect(subject).to receive(:deploy_service).with('1234567', 'kontena-test-wordpress', {:strategy => 'ha'})
          subject.deploy(options)
        end

        context 'when giving service option' do
          it 'deploys only given services' do
            allow(subject).to receive(:current_dir).and_return("kontena-test")
            allow(options).to receive(:service).and_return(['wordpress'])
            allow(subject).to receive(:deploy_services).and_return({})
            expect(subject).to receive(:create).once.with('wordpress', anything).and_return({})
            expect(subject).not_to receive(:create).with('mysql', services['mysql'])

            subject.deploy(options)
          end
        end
      end

    end
  end
end
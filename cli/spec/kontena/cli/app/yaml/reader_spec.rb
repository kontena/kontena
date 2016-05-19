require_relative '../../../../spec_helper'
require 'kontena/cli/apps/yaml/reader'

describe Kontena::Cli::Apps::YAML::Reader do
  include FixturesHelpers

  def absolute_yaml_path(file = 'kontena.yml')
    "#{Dir.pwd}/#{file}"
  end

  let(:subject) do
    described_class.new('kontena.yml')
  end

  let(:service_extender) do
    spy
  end

  let(:valid_result) do
    {
      'wordpress' => {
        'image' => 'wordpress:4.1',
        'ports' => ['80:80'],
        'links' => ['mysql:mysql'],
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
  end

  let(:valid_v2_result) do
    {
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
          'networks' => ['front-tier', 'back-tier'],
          'secrets' => []
        },
        'mysql' => {
          'image' => 'mysql:5.6',
          'stateful' => true,
          'environment' => ['MYSQL_ROOT_PASSWORD=test_secret'],
          'volumes' => ['mysql-data:/var/lib/mysql'],
          'networks' => ['back-tier'],
          'secrets' => []
        }
      },
      'volumes' => {
        'mysql-data' => { 'driver' => 'local' }
      },
      'networks' => {
        'front-tier' => { 'driver' => 'bridge' },
        'back-tier' => { 'driver' => 'bridge' }
      }
    }
  end

  describe '#initialize' do
    before(:each) do
      allow(File).to receive(:read)
        .with(absolute_yaml_path('kontena.yml'))
        .and_return(fixture('kontena.yml'))
      allow(File).to receive(:read)
        .with(absolute_yaml_path('docker-compose.yml'))
        .and_return(fixture('docker-compose.yml'))
    end

    it 'reads given file' do
      expect(File).to receive(:read)
        .with(absolute_yaml_path)
        .and_return(fixture('kontena.yml'))
      subject
    end

    context 'variable interpolation' do
      before(:each) do
        allow(ENV).to receive(:key?).and_return(true)
        allow(ENV).to receive(:[]).with('TAG').and_return('4.1')
        allow(ENV).to receive(:[]).with('project').and_return('test')
        allow(ENV).to receive(:[]).with('grid').and_return('test-grid')
        allow(ENV).to receive(:[]).with('MYSQL_IMAGE').and_return('mariadb:latest')
      end

      it 'interpolates $VAR variables' do
        allow(File).to receive(:read)
          .with(absolute_yaml_path)
          .and_return(fixture('kontena-with-variables.yml'))
        services = subject.yaml
        expect(services['wordpress']['image']).to eq('wordpress:4.1')
      end

      it 'interpolates ${VAR} variables' do
        allow(File).to receive(:read)
          .with(absolute_yaml_path)
          .and_return(fixture('kontena-with-variables.yml'))
        services = subject.yaml
        expect(services['mysql']['image']).to eq('mariadb:latest')
      end

      it 'warns about empty variables' do
        allow(File).to receive(:read)
          .with(absolute_yaml_path)
          .and_return(fixture('kontena-with-variables.yml'))
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
      allow(ENV).to receive(:[]).with('project').and_return('test')
      allow(ENV).to receive(:[]).with('grid').and_return('test-grid')
      allow(File).to receive(:read)
        .with(absolute_yaml_path)
        .and_return(fixture('kontena-with-variables.yml'))
      services = subject.execute[:result]
      expect(services['mysql']['environment'].first).to eq('INTERNAL_VAR=$INTERNAL_VAR')
    end
  end

  describe '#v2?' do
    context 'version 1' do
      it 'returns false' do
        allow(File).to receive(:read)
          .with(absolute_yaml_path('docker-compose.yml'))
          .and_return(fixture('docker-compose.yml'))
        allow(File).to receive(:read)
          .with(absolute_yaml_path('kontena.yml'))
          .and_return(fixture('kontena.yml'))
        expect(subject.v2?).to be_falsey
      end
    end
    context 'version 2' do
      it 'returns true' do
        allow(File).to receive(:read)
          .with(absolute_yaml_path('docker-compose_v2.yml'))
          .and_return(fixture('docker-compose_v2.yml'))
        allow(File).to receive(:read)
          .with(absolute_yaml_path('kontena.yml'))
          .and_return(fixture('kontena_v2.yml'))
        expect(subject.v2?).to be_truthy
      end
    end
  end

  describe '#execute' do
    before(:each) do
      allow(ENV).to receive(:[]).with('project').and_return('test')
      allow(ENV).to receive(:[]).with('grid').and_return('test-grid')

      allow(File).to receive(:read)
        .with(absolute_yaml_path('kontena.yml'))
        .and_return(fixture('kontena.yml'))
      allow(File).to receive(:read)
        .with(absolute_yaml_path('docker-compose.yml'))
        .and_return(fixture('docker-compose.yml'))
    end

    it 'extends services' do
      docker_compose_yml = YAML.load(fixture('docker-compose.yml') % { project: 'test' })
      wordpress_options = {
        'stateful' => true,
        'environment' => ['WORDPRESS_DB_PASSWORD=test_secret'],
        'instances' => 2,
        'deploy' => { 'strategy' => 'ha' }
      }
      mysql_options = { 'stateful' => true, 'environment' => ['MYSQL_ROOT_PASSWORD=test_secret'] }
      expect(Kontena::Cli::Apps::YAML::ServiceExtender).to receive(:new)
        .with(wordpress_options)
        .once
        .and_return(service_extender)
      expect(Kontena::Cli::Apps::YAML::ServiceExtender).to receive(:new)
        .with(mysql_options)
        .once
        .and_return(service_extender)
      expect(service_extender).to receive(:extend).with(docker_compose_yml['wordpress'])
      expect(service_extender).to receive(:extend).with(docker_compose_yml['mysql'])

      subject.execute
    end

    context 'environment variables' do
      it 'converts env hash to array' do
        result = subject.execute[:result]
        expect(result['wordpress']['environment']).to eq(['WORDPRESS_DB_PASSWORD=test_secret'])
      end

      it 'does nothing to env array' do
        result = subject.execute[:result]
        expect(result['mysql']['environment']).to eq(['MYSQL_ROOT_PASSWORD=test_secret'])
      end
    end
    it 'returns result hash' do
      outcome = subject.execute
      expect(outcome[:result]).to eq(valid_result)
    end

    it 'returns validation errors' do
      allow(File).to receive(:read)
        .with(absolute_yaml_path('kontena.yml'))
        .and_return(fixture('kontena-invalid.yml'))
      outcome = subject.execute
      expect(outcome[:errors].size).to eq(1)
    end
  end
end

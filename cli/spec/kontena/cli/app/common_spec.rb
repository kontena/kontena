require_relative "../../../spec_helper"
require "kontena/cli/apps/common"

describe Kontena::Cli::Apps::Common do
  include ClientHelpers
  include FixturesHelpers

  let(:subject) do
    Class.new { include Kontena::Cli::Apps::Common}.new
  end

  let(:kontena_yml) do
    fixture('kontena.yml')
  end

  let(:kontena_v2_yml) do
    fixture('kontena_v2.yml')
  end

  let(:docker_compose_yml) do
    fixture('docker-compose.yml')
  end

  let(:mysql_yml) do
    fixture('mysql.yml')
  end

  let(:health_yml) do
    fixture('health.yml')
  end

  let(:services) do
    {
      'wordpress' => {
        'image' => 'wordpress:4.1',
        'ports' => ['80:80']
      }
    }
  end

  describe '#service_prefix' do
    it 'returns given project name' do
      allow(subject).to receive(:project_name).and_return('test')
      expect(subject.service_prefix).to eq('test')
    end

    it 'returns app name from yaml if project name not given' do
      allow(subject).to receive(:project_name).and_return(nil)
      allow(subject).to receive(:filename).and_return('kontena.yml')
      allow(File).to receive(:read).with("#{Dir.getwd}/docker-compose_v2.yml").and_return(docker_compose_yml)
      allow(File).to receive(:read).with("#{Dir.getwd}/kontena.yml").and_return(kontena_v2_yml)
      expect(subject.service_prefix).to eq('test-project')
    end

    it 'returns current dir as default' do
      allow(subject).to receive(:project_name).and_return(nil)
      allow(subject).to receive(:filename).and_return('kontena.yml')
      allow(subject).to receive(:project_name_from_yaml).and_return(nil)
      allow(subject).to receive(:current_dir).and_return('working_dir')
      expect(subject.service_prefix).to eq('working_dir')
    end
  end

  describe '#load_from_yaml' do
    before(:each) do
      allow(File).to receive(:read).with("#{Dir.getwd}/kontena.yml").and_return(kontena_yml)
      allow(File).to receive(:read).with("#{Dir.getwd}/health.yml").and_return(health_yml)
      allow(File).to receive(:read).with("#{Dir.getwd}/docker-compose.yml").and_return(docker_compose_yml)
    end

    it 'populates env variables' do
      services = subject.services_from_yaml('kontena.yml',[],'load-test')
      expect(ENV['grid']).to eq('test-grid')
      expect(ENV['project']).to eq('load-test')
    end

    it 'returns services from given YAML file' do
      services = subject.services_from_yaml('kontena.yml',[],'')
      expect(services['wordpress']).not_to be_nil
    end

    it 'aborts on validation failure' do
      allow_any_instance_of(Kontena::Cli::Apps::YAML::Validator).to receive(:validate)
        .and_return({ :errors => [{ 'wordress' => [] }], :notifications => [] })
      expect { subject.services_from_yaml('kontena.yml',[],'') }.to raise_error(SystemExit)
    end

    it 'returns given service from given YAML file' do
      services = subject.services_from_yaml('kontena.yml',['wordpress'],'')
      expect(services['wordpress']).not_to be_nil
      expect(services.size).to eq(1)
    end

    it 'populates health check' do
      services = subject.services_from_yaml('health.yml',['web'],'')
      expect(services['web']).not_to be_nil
      expect(services['web']['health_check']).not_to be_nil
    end
  end
end

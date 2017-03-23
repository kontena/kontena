require 'kontena/cli/apps/init_command'

describe Kontena::Cli::Apps::InitCommand do
  include FixturesHelpers

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:app_json) do
    fixture('app.json')
  end

  before(:each) do
    allow(File).to receive(:exist?).and_return false
    allow(subject).to receive(:create_yml).and_return nil
    allow(subject).to receive(:create_dockerfile?).and_return false
    allow(subject).to receive(:create_env_file).and_return nil
    allow(subject).to receive(:create_docker_compose_yml?).and_return false
    allow(Kontena::Cli::Apps::KontenaYmlGenerator).to receive(:new).and_return spy
  end

  describe '#execute' do
    it 'detects Dockerfile' do
      expect(File).to receive(:exist?).with('Dockerfile').once.and_return true
      subject.run([])
    end

    it 'reads Procfile' do
      allow(File).to receive(:exist?).with('Procfile').once.and_return true
      expect(File).to receive(:read).with('Procfile').once.and_return 'web: bundle exec rails s'
      subject.run([])
    end

    it 'reads app.json file' do
      allow(File).to receive(:exist?).with('app.json').once.and_return true
      expect(File).to receive(:read).with('app.json').once.and_return '{}'
      subject.run([])
    end

    it 'asks creation of docker-compose.yml' do
      expect(subject).to receive(:create_docker_compose_yml?).and_return false
      subject.run([])
    end

    it 'creates docker-compose.yml if accepted' do
      allow(subject).to receive(:create_docker_compose_yml?).and_return true
      generator = spy
      generator_klass = Kontena::Cli::Apps::DockerComposeGenerator
      expect(generator_klass).to receive(:new).with('docker-compose.yml').and_return(generator)
      expect(generator).to receive(:generate).with({}, [], nil)
      subject.run([])
    end

    it 'passes Procfile services to docker-compose.yml creation' do
      allow(File).to receive(:exist?).with('Procfile').once.and_return true
      allow(File).to receive(:read).with('Procfile').once.and_return 'web: bundle exec rails s'
      allow(subject).to receive(:create_docker_compose_yml?).and_return true
      generator = spy
      generator_klass = Kontena::Cli::Apps::DockerComposeGenerator
      expect(generator_klass).to receive(:new).with('docker-compose.yml').and_return(generator)
      expect(generator).to receive(:generate).with({ 'web' => 'bundle exec rails s' }, [], nil)
      subject.run([])
    end

    it 'passes app.json options to docker-compose.yml creation' do
      expect(File).to receive(:exist?).with('app.json').and_return true
      expect(File).to receive(:read).with('app.json').and_return app_json
      allow(subject).to receive(:create_docker_compose_yml?).and_return true
      generator = spy
      generator_klass = Kontena::Cli::Apps::DockerComposeGenerator
      expect(generator_klass).to receive(:new).with('docker-compose.yml').and_return(generator)
      expect(generator).to receive(:generate).with({}, ["openredis","mongolab:shared-single-small"], nil)
      subject.run([])
    end

    it 'creates .env file' do
      allow(File).to receive(:exist?).with('app.json').and_return true
      allow(File).to receive(:read).with('app.json').and_return app_json
      allow(subject).to receive(:create_docker_compose_yml?).and_return true
      generator = spy
      generator_klass = Kontena::Cli::Apps::DockerComposeGenerator
      allow(generator_klass).to receive(:new).with('docker-compose.yml').and_return(generator)
      app_env = JSON.parse(app_json)['env']
      expect(subject).to receive(:create_env_file).with(app_env).and_return nil
      subject.run([])
    end

    it 'creates kontena.yml from docker-compose.yml' do
      allow(File).to receive(:exist?).with('docker-compose.yml').and_return true
      generator = spy
      generator_klass = Kontena::Cli::Apps::KontenaYmlGenerator
      expect(generator_klass).to receive(:new).with(nil, 'cli').and_return(generator)
      expect(generator).to receive(:generate_from_compose_file).with('docker-compose.yml')
      subject.run([])
    end

    context 'when docker-compose.yml not created' do
      it 'creates dummy kontena.yml' do
        allow(File).to receive(:exist?).with('docker-compose.yml').and_return false
        generator = spy
        generator_klass = Kontena::Cli::Apps::KontenaYmlGenerator
        expect(generator_klass).to receive(:new).with(nil, 'cli').and_return(generator)
        expect(generator).to receive(:generate).with({}, [], nil)
        subject.run([])
      end
    end
  end
end

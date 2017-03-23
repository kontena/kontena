require "kontena/cli/apps/build_command"

describe Kontena::Cli::Apps::BuildCommand do
  include FixturesHelpers

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:kontena_yml) do
    fixture('kontena-build.yml')
  end

  let(:mysql_yml) do
    fixture('kontena.yml')
  end

  let(:docker_compose_yml) do
    fixture('docker-compose.yml')
  end

  let(:settings) do
    {'current_server' => 'alias',
     'servers' => [
         {
           'name' => 'some_master',
           'url' => 'some_master'
         }
     ]
    }
  end

  describe '#execute' do
    before(:each) do
      allow(subject).to receive(:settings).and_return(settings)
      allow(subject).to receive(:current_dir).and_return("kontena-test")
      allow(File).to receive(:exists?).and_return(true)
      allow(File).to receive(:read).with("#{Dir.getwd}/kontena.yml").and_return(kontena_yml)
      allow(File).to receive(:read).with("#{Dir.getwd}/docker-compose.yml").and_return(docker_compose_yml)
    end

    it 'requests process_docker_images with services from yaml' do
      expect(subject).to receive(:process_docker_images) do |services, force_build, no_cache|
        expect(services.keys).to eq(['wordpress', 'mysql'])
      end
      subject.run([])
    end

    it 'requests process_docker_images with force_build' do
      expect(subject).to receive(:process_docker_images).with(anything, true, anything)
      subject.run([])
    end

    it 'requests process_docker_images with given no_cache option' do
      expect(subject).to receive(:process_docker_images).with(anything, anything, true)
      subject.run(['--no-cache'])
    end

    it 'raises error if no services found with build options' do
      allow(File).to receive(:read).with("#{Dir.getwd}/kontena.yml").and_return(mysql_yml)
      expect(subject).not_to receive(:process_docker_images)
      expect {
        subject.run([])
      }.to exit_with_error
    end
  end
end

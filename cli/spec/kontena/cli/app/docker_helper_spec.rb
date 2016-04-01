require_relative "../../../spec_helper"
require "kontena/cli/apps/docker_helper"

describe Kontena::Cli::Apps::DockerHelper do

  let(:subject) do
    Class.new { include Kontena::Cli::Apps::DockerHelper}.new
  end

  let(:services_with_valid_hooks) do
    {
        'test_service' => {
            'build' => '.',
            'image' => 'test_service',
            'hooks' => {
              'pre_build' => [
                { 'cmd' => "echo PREBUILD1", 'name' => 'hook1' },
                { 'cmd' => "echo PREBUILD2", 'name' => 'hook2' }
              ]
            }
        }
    }
  end

  let(:services_with_invalid_hook) do
    {
        'test_service' => {
            'build' => '.',
            'image' => 'test_service',
            'hooks' => {
              'pre_build' => [
                { 'cmd' => "echo PREBUILD1", 'name' => 'hook1' },
                { 'cmd' => "some_non_existing_command", 'name' => 'failing hook' },
              ]
            }
        }
    }
  end

  let(:services_with_no_hook) do
    {
        'test_service' => {
            'build' => '.',
            'image' => 'test_service',
        }
    }
  end

  describe '#validate_image_name' do
    context 'when image name is valid' do
      it 'returns true' do
        expect(subject.validate_image_name('registry.kontena.local/image-name:latest')).to be_truthy
        expect(subject.validate_image_name('my-registry.com/organization/image_name:latest')).to be_truthy
        expect(subject.validate_image_name('my-registry.com:5000/organization/image_name:latest')).to be_truthy
        expect(subject.validate_image_name('mysql:5.1')).to be_truthy
        expect(subject.validate_image_name('wordpress')).to be_truthy
      end

    end
  end

  describe '#validate_image_name' do
    context 'when image name is invalid' do
      it 'returns false' do
        expect(subject.validate_image_name('registry.kontena.local/image-name:')).to be_falsey
        expect(subject.validate_image_name('mysql 5.1')).to be_falsey
        expect(subject.validate_image_name('*.mydomain.com/mysql')).to be_falsey
      end
    end
  end

  describe '#run_pre_build_hook' do
    
    context 'when hook defined' do
      it 'runs the hook' do
        allow(subject).to receive(:build_docker_image)
        allow(subject).to receive(:push_docker_image)
        expect(subject).to receive(:system).with("echo PREBUILD1"). and_return(true)
        expect(subject).to receive(:system).with("echo PREBUILD2"). and_return(true)

        subject.process_docker_images(services_with_valid_hooks)
      end

      it 'fails to run the hook' do
        allow(subject).to receive(:build_docker_image)
        allow(subject).to receive(:push_docker_image)
        expect(subject).to receive(:system).with("echo PREBUILD1"). and_return(true)
        expect(subject).to receive(:system).with("some_non_existing_command"). and_return(false)

        expect {
          subject.process_docker_images(services_with_invalid_hook)
        }.to raise_error(SystemExit)
      end
    end
    context 'when no hook defined' do
      it 'runs no hooks' do
        allow(subject).to receive(:build_docker_image)
        allow(subject).to receive(:push_docker_image)
        expect(subject).not_to receive(:run_pre_build_hook)

        subject.process_docker_images(services_with_no_hook)
      end
    end
  end

end

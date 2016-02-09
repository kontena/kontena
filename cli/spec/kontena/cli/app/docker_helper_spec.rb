require_relative "../../../spec_helper"
require "kontena/cli/apps/docker_helper"

describe Kontena::Cli::Apps::DockerHelper do

  let(:subject) do
    Class.new { include Kontena::Cli::Apps::DockerHelper}.new
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
end

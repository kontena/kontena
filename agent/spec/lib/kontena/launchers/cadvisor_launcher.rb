require_relative '../../../spec_helper'

describe Kontena::Launchers::Cadvisor do

  let(:subject) { described_class.new(false) }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#initialize' do
    it 'calls #start by default' do
      expect_any_instance_of(described_class).to receive(:start)
      subject = described_class.new
      sleep 0.01
    end
  end

  describe '#start' do
    it 'pulls image and creates a container' do
      expect(subject.wrapped_object).to receive(:pull_image).with(subject.image)
      expect(subject.wrapped_object).to receive(:create_container).with(subject.image)
      subject.start
    end

    it 'retries 4 times if Docker::Error::ServerError is raised' do
      allow(subject.wrapped_object).to receive(:start_cadvisor) do
        raise Docker::Error::ServerError
      end
      expect(subject.wrapped_object).to receive(:start_cadvisor).exactly(5).times
      subject.start
      sleep 0.01
    end
  end

  describe '#volume_mappings' do
    it 'returns only one mapping for kontena cadvisor image (for nsenter)' do
      allow(subject.wrapped_object).to receive(:kontena_image?).and_return(true)
      expect(subject.volume_mappings.keys).to eq(['/host'])
    end

    it 'returns cadvisor default mappings when non-kontena image is used' do
      allow(subject.wrapped_object).to receive(:kontena_image?).and_return(false)
      expect(subject.volume_mappings.keys).to eq(['/rootfs', '/var/run', '/sys', '/var/lib/docker'])
    end
  end

  describe '#kontena_image?' do
    it 'returns true when kontena/cadvisor is used' do
      stub_const("#{described_class.name}::CADVISOR_IMAGE", 'kontena/cadvisor')
      expect(subject.kontena_image?).to be_truthy
    end

    it 'returns false when custom image is used' do
      stub_const("#{described_class.name}::CADVISOR_IMAGE", 'google/cadvisor')
      expect(subject.kontena_image?).to be_falsey
    end
  end
end

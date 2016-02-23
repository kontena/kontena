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
end

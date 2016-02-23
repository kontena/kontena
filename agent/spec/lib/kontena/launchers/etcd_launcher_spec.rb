require_relative '../../../spec_helper'

describe Kontena::Launchers::Etcd do

  let(:subject) { described_class.new(false) }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#initialize' do
    it 'calls #start by default' do
      expect_any_instance_of(described_class).to receive(:start)
      subject = described_class.new
      sleep 0.01
    end

    it 'subscribes to network_adapter:start event' do
      expect(subject.wrapped_object).to receive(:on_overlay_start)
      Celluloid::Notifications.publish('network_adapter:start', {})
      sleep 0.01
    end
  end

  describe '#start' do
    it 'pulls image' do
      expect(subject.wrapped_object).to receive(:pull_image)
      subject.start
    end
  end

  describe '#on_overlay_start' do
    it 'starts etcd' do
      expect(subject.wrapped_object).to receive(:start_etcd).and_return(true)
      subject.on_overlay_start('topic', {})
    end

    it 'retries 4 times if Docker::Error::ServerError is raised' do
      allow(subject.wrapped_object).to receive(:start_etcd) do
        raise Docker::Error::ServerError
      end
      expect(subject.wrapped_object).to receive(:start_etcd).exactly(5).times
      subject.on_overlay_start('topic', {})
    end
  end

  describe '#start_etcd' do
    it 'creates etcd containers after image is pulled' do
      allow(subject.wrapped_object).to receive(:image_pulled?).and_return(true)
      expect(subject.wrapped_object).to receive(:create_data_container)
      expect(subject.wrapped_object).to receive(:create_container)
      subject.start_etcd({})
    end

    it 'waits for image pull' do
      expect(subject.wrapped_object).not_to receive(:create_data_container)
      expect {
        Timeout.timeout(0.1) do
          subject.start_etcd({})
        end
      }.to raise_error(Timeout::Error)
    end
  end

  describe '#pull_image' do
    it 'does nothing if image already exists' do
      image = 'kontena/etcd:2.2.4'
      allow(Docker::Image).to receive(:exist?).with(image).and_return(true)
      expect(Docker::Image).not_to receive(:create)
      subject.pull_image(image)
    end

    it 'sets image_pulled flag if image already exists' do
      image = 'kontena/etcd:2.2.4'
      allow(Docker::Image).to receive(:exist?).with(image).and_return(true)
      subject.pull_image(image)
      expect(subject.image_pulled?).to be_truthy
    end

    it 'pulls image if it does not exist' do
      image = 'kontena/etcd:2.2.4'
      allow(Docker::Image).to receive(:exist?).with(image).and_return(false)
      expect(Docker::Image).to receive(:create).with({'fromImage' => image})
      subject.after(0.01) {
        allow(Docker::Image).to receive(:exist?).with(image).and_return(true)
      }
      subject.pull_image(image)
    end
  end
end

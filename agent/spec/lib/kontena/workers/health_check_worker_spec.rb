require_relative '../../../spec_helper'

describe Kontena::Workers::HealthCheckWorker do

  let(:queue) { Queue.new }
  let(:subject) { described_class.new(queue, false) }
  let(:container) { spy(:container, id: 'foo', labels: {'io.kontena.health_check.uri' => '/'}) }
  let(:container_not_to_check) { spy(:container, id: 'foo', labels: {}) }


  before(:each) do
    Celluloid.boot
  end

  after(:each) { Celluloid.shutdown }

  describe '#start' do

    it 'starts container checks' do
      allow(Docker::Container).to receive(:all).and_return([container, container_not_to_check])
      expect(subject.wrapped_object).to receive(:start_container_check).twice
      subject.start
    end
  end

  describe '#stop' do
    it 'stops all checks' do
      worker = spy(:worker, :alive? => true)
      subject.workers[container.id] = worker
      expect(subject.wrapped_object).to receive(:stop_container_check).once.with(container.id)
      subject.stop
    end
  end

  describe '#start_container_check' do
    it 'does nothing if worker actor already exist' do
      expect(Kontena::Workers::ContainerHealthCheckWorker).not_to receive(:new)
      subject.workers[container.id] = spy(:container_log_worker)
      subject.start_container_check(container)
    end

    it 'does nothing if health check not needed' do
      expect(Kontena::Workers::ContainerHealthCheckWorker).not_to receive(:new)
      subject.workers[container.id] = spy(:container_log_worker)
      subject.start_container_check(container_not_to_check)
    end

    it 'creates new container_health_check_worker actor' do
      worker = spy(:container_log_worker)
      expect(Kontena::Workers::ContainerHealthCheckWorker).to receive(:new).and_return(worker)
      subject.start_container_check(container)
    end
  end

  describe '#stop_container_check' do
    it 'terminates worker if it exist' do
      worker = spy(:worker, :alive? => true)
      subject.workers[container.id] = worker
      expect(Celluloid::Actor).to receive(:kill).with(worker)
      subject.stop_container_check(container.id)
    end
  end

  describe '#on_container_event' do
    it 'stops check on die' do
      expect(subject.wrapped_object).to receive(:stop_container_check).once.with('foo')
      subject.on_container_event('topic', double(:event, id: 'foo', status: 'die'))
      sleep 0.01
    end

    it 'starts check on start' do
      allow(Docker::Container).to receive(:get).and_return(container)
      allow(subject.wrapped_object).to receive(:queue_processing?).and_return(true)
      expect(subject.wrapped_object).to receive(:start_container_check).once.with(container)
      subject.on_container_event('topic', double(:event, id: 'foo', status: 'start'))
    end

    it 'does not start check on create' do
      allow(Docker::Container).to receive(:get).and_return(container)
      allow(subject.wrapped_object).to receive(:queue_processing?).and_return(true)
      expect(subject.wrapped_object).not_to receive(:start_container_check)
      subject.on_container_event('topic', double(:event, id: 'foo', status: 'create'))
    end
  end
end

require_relative '../../../spec_helper'

describe Kontena::Workers::ContainerStarterWorker do

  let(:container) { spy(:container) }
  let(:network_adapter) { spy(:network_adapter) }
  let(:subject) { described_class.new }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#initialize' do
    it 'subscribes to network_adapter:start event' do
      expect(subject.wrapped_object).to receive(:on_overlay_start)
      Celluloid::Notifications.publish('network_adapter:start', {})
      sleep 0.1
    end
  end

  describe '#ensure_container_running' do

    it 'starts stopped service container' do
      expect(container).to receive(:running?).and_return(false)
      expect(container).to receive(:restarting?).and_return(false)
      expect(container).to receive(:restart_policy).and_return({'Name' => 'always'})
      expect(container).to receive(:service_container?).and_return(true)
      expect(container).to receive(:start)

      subject.ensure_container_running(container)
    end

    it 'does not start non-service container' do
      expect(container).to receive(:running?).and_return(false)
      expect(container).to receive(:restarting?).and_return(false)
      expect(container).to receive(:restart_policy).and_return({'Name' => 'always'})
      expect(container).to receive(:service_container?).and_return(false)
      expect(container).not_to receive(:start)

      subject.ensure_container_running(container)
    end

    it 'does not start running container' do
      expect(container).to receive(:running?).and_return(true)
      expect(container).not_to receive(:start)

      subject.ensure_container_running(container)
    end

    it 'does not start service container with restart policy not "always"' do
      expect(container).to receive(:running?).and_return(false)
      expect(container).to receive(:restarting?).and_return(false)
      expect(container).to receive(:restart_policy).and_return({'Name' => 'never'})
      expect(container).not_to receive(:start)

      subject.ensure_container_running(container)
    end

  end

end

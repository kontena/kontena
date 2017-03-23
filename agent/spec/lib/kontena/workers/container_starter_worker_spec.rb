
describe Kontena::Workers::ContainerStarterWorker do

  let(:network_adapter) { double(:network_adapter) }
  let(:subject) { described_class.new }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#ensure_container_running' do
    context 'for a stopped server container' do
      let :container do
        double(:container, name: 'test',
          running?: false,
          restarting?: false,
          service_container?: true,
          autostart?: true,
        )
      end

      it 'starts the container' do
        expect(container).to receive(:start)

        subject.ensure_container_running(container)
      end
    end

    context 'for a stopped non-service container' do
      let :container do
        double(:container, name: 'test',
          running?: false,
          restarting?: false,
          service_container?: false,
          autostart?: true,
        )
      end

      it 'does not start the container' do
        expect(container).not_to receive(:start)

        subject.ensure_container_running(container)
      end
    end

    context 'for a running container' do
      let :container do
        double(:container, name: 'test',
          running?: true,
        )
      end

      it 'does not start the container' do
        expect(container).not_to receive(:start)

        subject.ensure_container_running(container)
      end
    end

    context 'for a autostart => never container' do
      let :container do
        double(:container, name: 'test',
          running?: false,
          restarting?: false,
          autostart?: false,
        )
      end

      it 'does not start service container with restart policy not "always"' do
        expect(container).not_to receive(:start)

        subject.ensure_container_running(container)
      end
    end
  end
end

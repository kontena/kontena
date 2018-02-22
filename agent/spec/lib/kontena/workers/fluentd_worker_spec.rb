describe Kontena::Workers::FluentdWorker do

  let(:subject) { described_class.new(false) }

  before(:each) do
    Celluloid.boot
  end

  after(:each) { Celluloid.shutdown }

  let(:info) do
    Node.new('name' => 'node-1',
      'grid' => {
        'name' => 'terminal-a',
        'logs' => {
          'forwarder' => 'fluentd',
          'opts' => {
            'fluentd-address' => 'foo:12345'
          }
        }
      }
    )
  end

  let(:fluentd) do
    instance_double(Fluent::Logger::FluentLogger)
  end

  describe '#configure' do

    it 'creates fluentd logger and starts forwarding' do
      expect(Fluent::Logger::FluentLogger).to receive(:new).and_return(fluentd)

      subject.configure(info)
      expect(subject.processing?).to be_truthy
    end

    context "after de-configuring the fluentd forwarder" do
      it 'removes fluentd logger and stops forwarding' do
        expect(Fluent::Logger::FluentLogger).to receive(:new).and_return(fluentd)
        subject.configure(info)
        expect(fluentd).to receive(:close)

        info.grid['logs'] = { 'driver' => 'none'}
        subject.configure(info)
        expect(subject.processing?).to be_falsey
      end
    end
  end

  describe '#on_log_event' do
    let(:log_event) do
      {
        id: 1234567890,
        service: 'nginx',
        stack: 'web',
        instance: 1,
        time: Time.now.utc.xmlschema,
        type: 'stdout',
        data: 'foo bar'
      }
    end

    before :each do
      expect(Fluent::Logger::FluentLogger).to receive(:new).and_return(fluentd)
      subject.configure(info)
    end

    it 'sends proper event to fluentd' do
      expect(fluentd).to receive(:post).with('web.nginx.1', {log: 'foo bar', source: 'stdout', node: 'node-1', grid: 'terminal-a', stack: 'web', service: 'nginx', instance_number: 1})

      subject.on_log_event(log_event)
    end

    it 'does not post event if not forwarding' do
      expect(fluentd).not_to receive(:post)
      expect(subject.wrapped_object).to receive(:processing?).and_return(false)

      subject.on_log_event(log_event)
    end
  end

end

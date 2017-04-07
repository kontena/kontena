describe Kontena::Workers::FluentdWorker do

  let(:subject) { described_class.new(false) }

  before(:each) do
    Celluloid.boot
  end

  after(:each) { Celluloid.shutdown }

  describe '#configure' do

    let(:info) do
      Node.new(
        'grid' => {
          'logs' => {
            'forwarder' => 'fluentd',
            'opts' => {
              'fluentd-address' => 'foo:12345'
            }
          }
        }
      )
    end

    it 'creates fluentd logger and starts forwarding' do
      subject.configure(info)
      expect(subject.wrapped_object.instance_variable_get('@fluentd')).not_to be_nil
      expect(subject.wrapped_object.instance_variable_get('@forwarding')).to be_truthy
    end

    context "after de-configuring the fluentd forwarder" do
      before do
        subject.configure(info)
        info.grid['logs'] = { 'driver' => 'none'}
      end

      it 'removes fluentd logger and stops forwarding' do
        expect_any_instance_of(Fluent::Logger::FluentLogger).to receive(:close)
        subject.configure(info)
        expect(subject.wrapped_object.instance_variable_get('@fluentd')).to be_nil
        expect(subject.wrapped_object.instance_variable_get('@forwarding')).to be_falsey
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
    it 'sends proper event to fluentd' do
      fluentd = instance_double(Fluent::Logger::FluentLogger)
      subject.wrapped_object.instance_variable_set('@fluentd', fluentd)
      subject.wrapped_object.instance_variable_set('@forwarding', true)
      expect(fluentd).to receive(:post).with('web.nginx.1', {log: 'foo bar', source: 'stdout'})
      subject.on_log_event(log_event)
    end

    it 'does not post event if not forwarding' do
      fluentd = instance_double(Fluent::Logger::FluentLogger)
      subject.wrapped_object.instance_variable_set('@fluentd', fluentd)
      subject.wrapped_object.instance_variable_set('@forwarding', false)
      expect(fluentd).not_to receive(:post)
      subject.on_log_event(log_event)
    end

    it 'does not post event if no fluentd configured' do
      subject.wrapped_object.instance_variable_set('@fluentd', nil)
      subject.wrapped_object.instance_variable_set('@forwarding', true)
      expect_any_instance_of(Fluent::Logger::FluentLogger).not_to receive(:post)
      subject.on_log_event(log_event)
    end
  end

end

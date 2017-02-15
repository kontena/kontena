require_relative '../../../spec_helper'

describe Kontena::Workers::FluentdWorker do

  let(:subject) { described_class.new(false) }



  before(:each) do
    Celluloid.boot
  end

  after(:each) { Celluloid.shutdown }

  describe '#on_node_info' do

    let(:info) do
      {
        'grid' => {
          'logs' => {
            'driver' => 'fluentd',
            'opts' => {
              'fluentd-address' => 'foo:12345'
            }
          }
        }
      }
    end
    it 'creates fluentd logger and starts forwarding' do
      subject.on_node_info('agent:node_info', info)
      expect(subject.wrapped_object.instance_variable_get('@fluentd')).not_to be_nil
      expect(subject.wrapped_object.instance_variable_get('@forwarding')).to be_truthy
    end

    it 'removes fluentd logger and stops forwarding' do
      subject.on_node_info('agent:node_info', info)
      info['grid']['logs'] = { 'driver' => 'none'}
      expect_any_instance_of(Fluent::Logger::FluentLogger).to receive(:close)
      subject.on_node_info('agent:node_info', info)
      expect(subject.wrapped_object.instance_variable_get('@fluentd')).to be_nil
      expect(subject.wrapped_object.instance_variable_get('@forwarding')).to be_falsey
    end
  end

end

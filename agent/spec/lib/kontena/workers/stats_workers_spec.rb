require_relative '../../../spec_helper'

describe Kontena::Workers::StatsWorker do

  let(:queue) { Queue.new }
  let(:subject) { described_class.new(queue, false) }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#initialize' do
    it 'subscribes to agent:node_info channel' do
      expect(subject.wrapped_object).to receive(:on_node_info)
      Celluloid::Notifications.publish('agent:node_info')
      sleep 0.01
    end
  end

  describe '#on_node_info' do
    it 'initializes statsd client if node has statsd config' do
      info = {
        'grid' => {
          'stats' => {
            'statsd' => {
              'server' => '192.168.24.33',
              'port' => 8125
            }
          }
        }
      }
      expect(subject.statsd).to be_nil
      subject.on_node_info('agent:node_info', info)
      expect(subject.statsd).not_to be_nil
    end

    it 'does not initialize statsd if no statsd config exists' do
      info = {
        'grid' => {
          'stats' => {}
        }
      }
      expect(subject.statsd).to be_nil
      subject.on_node_info('agent:node_info', info)
      expect(subject.statsd).to be_nil
    end
  end

  describe '#send_statsd_metrics' do
    let(:event) do
      {
        id: 'aaaaaa',
        spec: {
          labels: {
            :'io.kontena.service.name' => 'foobar'
          }
        },
        cpu: {
          usage_pct: 12.32
        },
        memory: {
          usage: 24 * 1024 * 1024
        },
        filesystem: [],
        diskio: [],
        network: []
      }
    end

    let(:statsd) do
      spy(:statsd)
    end

    it 'sends statsd metrics' do
      allow(subject.wrapped_object).to receive(:statsd).and_return(statsd)
      expect(statsd).to receive(:gauge)
      subject.send_statsd_metrics('foobar', event)
    end
  end
end

require_relative '../../../spec_helper'

describe Kontena::Workers::NodeInfoWorker do

  let(:queue) { Queue.new }
  let(:subject) { described_class.new(queue, false) }

  before(:each) {
    Celluloid.boot
    allow(Docker).to receive(:info).and_return({
      'Name' => 'node-1',
      'Labels' => nil,
      'ID' => 'U3CZ:W2PA:2BRD:66YG:W5NJ:CI2R:OQSK:FYZS:NMQQ:DIV5:TE6K:R6GS'
    })
    allow(Net::HTTP).to receive(:get).and_return('8.8.8.8')
  }
  after(:each) { Celluloid.shutdown }

  describe '#initialize' do
    it 'subscribes to websocket:connected channel' do
      expect(subject.wrapped_object).to receive(:publish_node_info).once
      Celluloid::Notifications.publish('websocket:connected', {})
      sleep 0.01
    end
  end

  describe '#start' do
    it 'calls #publish_node_info' do
      stub_const('Kontena::Workers::NodeInfoWorker::PUBLISH_INTERVAL', 0.01)
      expect(subject.wrapped_object).to receive(:publish_node_info).at_least(:once)
      subject.async.start
      sleep 0.1
      subject.terminate
    end

    it 'calls #publish_node_info' do
      stub_const('Kontena::Workers::NodeInfoWorker::PUBLISH_INTERVAL', 0.01)
      expect(subject.wrapped_object).to receive(:publish_node_stats).at_least(:once)
      subject.async.start
      sleep 0.1
      subject.terminate
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

  describe '#publish_node_info' do
    before(:each) do
      allow(subject.wrapped_object).to receive(:interface_ip).with('eth1').and_return('192.168.66.2')
    end

    it 'adds node info to queue' do
      expect {
        subject.publish_node_info
      }.to change{ subject.queue.length }.by(1)
    end

    it 'contains docker id' do
      subject.publish_node_info
      info = subject.queue.pop
      expect(info[:data]['ID']).to eq('U3CZ:W2PA:2BRD:66YG:W5NJ:CI2R:OQSK:FYZS:NMQQ:DIV5:TE6K:R6GS')
    end

    it 'contains public ip' do
      subject.publish_node_info
      info = subject.queue.pop
      expect(info[:data]['PublicIp']).to eq('8.8.8.8')
    end

    it 'contains private ip' do
      subject.publish_node_info
      info = subject.queue.pop
      expect(info[:data]['PrivateIp']).to eq('192.168.66.2')
    end
  end

  describe '#publish_node_stats' do
    it 'adds node stats to queue' do
      expect {
        subject.publish_node_stats
      }.to change{ subject.queue.length }.by(1)
    end
  end

  describe '#public_ip' do
    it 'returns ip from env if set' do
      allow(ENV).to receive(:[]).with('KONTENA_PUBLIC_IP').and_return('128.105.39.11')
      expect(subject.public_ip).to eq('128.105.39.11')
    end

    it 'returns ip from akamai by default' do
      expect(subject.public_ip).to eq('8.8.8.8')
    end
  end

  describe '#private_ip' do
    it 'returns ip from env if set' do
      allow(ENV).to receive(:[]).with('KONTENA_PRIVATE_IP').and_return('192.168.2.10')
      expect(subject.private_ip).to eq('192.168.2.10')
    end

    it 'returns ip from private interface by default' do
      allow(subject.wrapped_object).to receive(:interface_ip).and_return('192.168.2.10')
      expect(subject.private_ip).to eq('192.168.2.10')
    end
  end
end

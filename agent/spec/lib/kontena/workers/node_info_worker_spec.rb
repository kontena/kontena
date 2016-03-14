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
end

require_relative '../../spec_helper'

describe Kontena::NodeInfoWorker do

  let(:queue) { Queue.new }
  let(:subject) { described_class.new(queue) }

  describe '#start!' do
    it 'returns thread' do
      allow(subject).to receive(:publish_node_info)
      allow(Docker::Container).to receive(:all).and_return([])
      expect(subject.start!).to be_instance_of(Thread)
    end

    it 'calls #publish_node_info' do
      expect(subject).to receive(:publish_node_info).once
      allow(Docker::Container).to receive(:all).and_return([])
      thread = subject.start!
      sleep 0.01
      thread.kill
    end
  end

  describe '#publish_node_info' do
    before(:each) do
      allow(subject).to receive(:interface_ip).with('eth1').and_return('192.168.66.2')
      allow(Net::HTTP).to receive(:get).and_return('8.8.8.8')
      allow(Docker).to receive(:info).and_return({
        'Name' => 'node-1',
        'Labels' => nil,
        'ID' => 'U3CZ:W2PA:2BRD:66YG:W5NJ:CI2R:OQSK:FYZS:NMQQ:DIV5:TE6K:R6GS'
      })
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
end

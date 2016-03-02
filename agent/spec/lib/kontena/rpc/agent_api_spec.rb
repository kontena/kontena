require_relative '../../../spec_helper'

describe Kontena::Rpc::AgentApi do

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#port_open?' do
    it 'returns {open: false} if port is not open' do
      expect(subject.port_open?('100.64.2.2', 6379, 0.01)).to eq({open: false})
    end

    it 'returns {open: true} if port is listening' do
      begin
        server = TCPServer.new 18232
        expect(subject.port_open?('127.0.0.1', 18232, 0.01)).to eq({open: true})
      ensure
        server.close if server
      end
    end
  end

  describe '#master_info' do
    it 'sends publishes event' do
      info = {'version' => '0.10.0'}
      expect(Celluloid::Notifications).to receive(:publish).with('websocket:connected', {master: info})
      subject.master_info(info)
      sleep 0.01
    end
  end

  describe '#node_info' do
    it 'sends publishes event' do
      info = {'version' => '0.10.0'}
      expect(Celluloid::Notifications).to receive(:publish).with('agent:node_info', info)
      subject.node_info(info)
      sleep 0.01
    end
  end
end

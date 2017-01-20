require_relative '../../../spec_helper'

describe Kontena::Rpc::AgentApi, :celluloid => true do
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
    let :info do
      {
        'version' => '1.1.0',
      }
    end

    it 'sends publishes event' do
      expect(Celluloid::Notifications).to receive(:publish).with('agent:node_info', info)
      subject.node_info(info)
      sleep 0.01
    end

    it 'updates an agent:node_info observable' do
      observable = Kontena::Actors::Observable.new(subscribe: 'agent:node_info')

      subject.node_info(info)

      observer = Class.new {
        include Celluloid
        include Kontena::Actors::Observer

        attr_accessor :node_info

        def initialize(observable)
          @node_info = observe observable, :node_info=
        end
      }.new(observable)

      expect(observer.node_info).to_not be_nil
      expect(observer.node_info.version).to eq '1.1.0'
    end
  end
end

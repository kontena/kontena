require_relative '../../../spec_helper'

describe Kontena::Rpc::AgentApi do

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
end

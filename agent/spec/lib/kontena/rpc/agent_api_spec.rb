
describe Kontena::Rpc::AgentApi do

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

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

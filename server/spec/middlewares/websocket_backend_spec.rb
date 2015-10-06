require_relative '../spec_helper'
require_relative '../../app/middlewares/websocket_backend'

describe WebsocketBackend do
  let(:app) { spy(:app) }
  let(:subject) { described_class.new(app) }

  before(:each) do
    stub_const('Server::VERSION', '0.9.1')
  end

  describe '#our_version' do
    it 'retuns baseline version with patch level 0' do
      expect(subject.our_version).to eq('0.9.0')
    end
  end

  describe '#valid_agent_version?' do
    it 'returns true when exact match' do
      expect(subject.valid_agent_version?('0.9.1')).to eq(true)
    end

    it 'returns true when patch level is greater' do
      expect(subject.valid_agent_version?('0.9.2')).to eq(true)
    end

    it 'returns true when patch level is less than' do
      expect(subject.valid_agent_version?('0.9.0')).to eq(true)
    end

    it 'returns false when minor version is different' do
      expect(subject.valid_agent_version?('0.8.4')).to eq(false)
    end

    it 'returns false when major version is different' do
      expect(subject.valid_agent_version?('1.0.1')).to eq(false)
    end
  end
end

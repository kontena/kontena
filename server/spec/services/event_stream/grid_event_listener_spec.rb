require_relative '../../spec_helper'

describe EventStream::GridEventListener do

  let(:subject) {
    EventStream::GridEventListener.new(grid)
  }
  let(:grid) { Grid.create({name: 'test-grid'}) }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }


  it 'subscribes correct pubsub channel' do
    expect(MongoPubsub).to receive(:subscribe).once.with('grids/test-grid')
    subject
  end

  describe '#add_client' do

    it 'creates new EventStream::Client with correct data' do
      ws = spy(:ws)

      subject.add_client(ws, ['*'])

      client = subject.clients.first
      expect(client.is_a?(EventStream::Client)).to be_truthy
      expect(client.socket).to eq(ws)
      expect(client.event_types).to eq(['*'])
    end

    it 'adds new client to clients' do
      ws = spy(:ws)
      expect{
        subject.add_client(ws, ['*'])
      }.to change{subject.clients.size}.by(1)
    end
  end

  describe '#remove_client' do
    it 'removes client with given socket from clients' do
      ws = spy(:ws)
      ws2 = spy(:ws)
      subject.add_client(ws, ['*'])
      subject.add_client(ws2, ['*'])

      expect{
        subject.remove_client(ws)
      }.to change{subject.clients.size}.by(-1)
    end
  end

  describe '#send_message' do
    it 'send message to valid clients' do
      ws = spy(:ws)
      ws2 = spy(:ws)
      ws3 = spy(:ws)
      subject.add_client(ws, ['*'])
      subject.add_client(ws2, ['*'])
      subject.add_client(ws3, ['service'])

      message = {'event_type' => 'grid', 'payload' => 'test'}
      expect(ws).to receive(:send).with(message.to_json)
      expect(ws2).to receive(:send).with(message.to_json)
      expect(ws3).not_to receive(:send)

      subject.send_message(message)
    end
  end

end
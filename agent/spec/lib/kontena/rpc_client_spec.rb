
describe Kontena::RpcClient, celluloid: true do

  let(:ws_client) { double(:ws_client, connected?: true) }
  let(:subject) { described_class.new(ws_client) }

  describe '#handle_response' do
    let(:session) { double(:session) }
    let(:request_id) { subject.request_id(session) }
    let(:response) { ['type', request_id, nil, {'foo' => 'bar'}] }

    it 'handles response to session if exist' do
      expect(session).to receive(:handle_response).once.with(response[3], response[2])
      subject.handle_response(response)
    end

    it 'does not handle response to session if id does not match' do
      response[1] = -1
      expect(session).not_to receive(:handle_response)
      subject.handle_response(response)
    end

    it 'removes request_id after passing response to session' do
      expect(session).to receive(:handle_response).once
      subject.handle_response(response)
      expect(subject.free_id(request_id)).to be_nil
    end
  end

  describe '#request_id' do
    it 'returns random integer' do
      id = subject.request_id(double(:session))
      expect(id).to be_instance_of(Fixnum)
    end
  end

  describe '#free_id' do
    it 'returns removed request if exist' do
      session = double(:session)
      id = subject.request_id(session)
      expect(subject.free_id(id)).to eq(session)
    end

    it 'returns nil if id does not exist' do
      expect(subject.free_id(1)).to be_nil
    end
  end
end

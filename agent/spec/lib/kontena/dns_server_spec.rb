require_relative '../../spec_helper'

describe Kontena::DnsServer do

  describe '#ask_from_server' do

    it 'returns rpc_client response' do
      client = spy
      allow(subject).to receive(:rpc_client).and_return(client)
      allow(client).to receive(:request).and_return(['10.1.1.1'])
      expect(client).to receive(:request).once
      subject.client=(client)
      response = subject.resolve_address('foo')
      expect(response).to eq(['10.1.1.1'])
    end
  end
end

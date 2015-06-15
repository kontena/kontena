require_relative '../../spec_helper'

describe Kontena::DnsServer do

  let(:etcd_url) { 'http://127.0.0.1:2379/v2/keys' }

  before(:each) do
    allow(described_class).to receive(:gateway).and_return('127.0.0.1')
  end

  describe '#resolve_address' do
    it 'returns single ip for a container' do
      stub_request(:get, "#{etcd_url}/kontena/dns/foo/foo-1").to_return(
        body: JSON.dump({
          action: 'get',
          node: {
            createdIndex: '1',
            modifiedIndex: '1',
            key: '/kontena/dns/foo/foo-1',
            value: '10.1.1.1'
          }
        })
      )
      response = subject.resolve_address('foo-1')
      expect(response).to eq(['10.1.1.1'])
    end

    it 'returns multiple ips for service' do
      stub_request(:get, "#{etcd_url}/kontena/dns/foo").to_return(
        body: JSON.dump({
          action: 'get',
          node: {
            createdIndex: '1',
            modifiedIndex: '1',
            dir: true,
            key: '/kontena/dns/foo',
            nodes: [
              {
                createdIndex: '1',
                modifiedIndex: '1',
                key: '/kontena/dns/foo/foo-1',
                value: '10.1.1.1'
              },
              {
                createdIndex: '1',
                modifiedIndex: '1',
                key: '/kontena/dns/foo/foo-2',
                value: '10.1.2.1'
              }
            ]
          }
        })
      )
      response = subject.resolve_address('foo')
      expect(response).to include('10.1.1.1')
      expect(response).to include('10.1.2.1')
    end
  end
end

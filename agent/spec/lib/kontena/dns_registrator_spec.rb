require_relative '../../spec_helper'

describe Kontena::DnsRegistrator do

  before(:each) do
    allow(described_class).to receive(:gateway).and_return('127.0.0.1')
  end

  let(:wp_container) do
    double(:container,
      id: '12345',
      info: {
        'Names' => ['/wordpress-1']
      },
      json: {
        'Config' => {
          'Labels' => {
            'io.kontena.container.overlay_cidr' => '10.81.1.9/19'
          }
        }
      }
    )
  end

  let(:unknown_container) do
    double(:container,
      id: '12345',
      info: {
        'Names' => ['/foobar']
      },
      json: {
        'Config' => {
          'Labels' => {}
        }
      }
    )
  end

  let(:created_container) do
    double(:container,
      id: '12345',
      info: {
        'Names' => ['/fresh_one-1']
      },
      json: {
      }
    )
  end

  describe '#register_container_dns' do
    it 'saves dns entry to etcd when service can be resolved' do
      client = spy
      allow(subject).to receive(:etcd).and_return(client)
      expect(client).to receive(:set).with('/kontena/dns/wordpress/wordpress-1', value: '10.81.1.9', ttl: 65)
      subject.register_container_dns(wp_container)
    end

    it 'caches container information' do
      client = spy
      allow(subject).to receive(:etcd).and_return(client)
      subject.register_container_dns(wp_container)
      expect(subject.cache[wp_container.id]).not_to be_nil
      sleep 0.1
    end

    it 'does not save dns entry when network settings does not exist' do
      client = spy
      allow(subject).to receive(:etcd).and_return(client)
      expect(client).not_to receive(:set)
      subject.register_container_dns(created_container)
    end

    it 'does not save dns entry when service cannot be resolved' do
      client = spy
      allow(subject).to receive(:etcd).and_return(client)
      expect(client).not_to receive(:set)
      subject.register_container_dns(unknown_container)
    end
  end
end

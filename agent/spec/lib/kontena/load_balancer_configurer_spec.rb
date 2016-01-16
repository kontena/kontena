require_relative '../../spec_helper'

describe Kontena::LoadBalancerConfigurer do

  before(:each) do
    allow_any_instance_of(described_class).to receive(:gateway).and_return('172.72.42.1')
    allow(subject).to receive(:etcd).and_return(etcd)
  end

  let(:etcd) { spy(:etcd) }
  let(:event) { spy(:event, id: 'foobar', status: 'start') }
  let(:container) {
    spy(:container, id: '12345',
      env_hash: {},
      labels: {
        'io.kontena.load_balancer.name' => 'lb',
        'io.kontena.service.name' => 'test-api'
      }
    )
  }
  let(:etcd_prefix) { described_class::ETCD_PREFIX }

  describe '#initialize' do
    it 'starts to listen container events' do
      expect(subject).to receive(:ensure_config).once.with(event)
      Kontena::Pubsub.publish('lb:ensure_config', event)

      expect(subject).to receive(:remove_config).once.with(event)
      Kontena::Pubsub.publish('lb:remove_config', event)
      sleep 0.05
    end
  end

  describe '#ensure_config' do
    it 'sets default values to etcd' do
      storage = {}
      allow(etcd).to receive(:set) do |key, value|
        storage[key] = value[:value]
      end
      subject.ensure_config(container)
      expected_values = {
        "#{etcd_prefix}/lb/services/test-api/balance" => 'roundrobin',
        "#{etcd_prefix}/lb/services/test-api/custom_settings" => nil,
        "#{etcd_prefix}/lb/services/test-api/virtual_path" => '/',
        "#{etcd_prefix}/lb/services/test-api/virtual_hosts" => nil,
      }
      expected_values.each do |k, v|
        expect(storage[k]).to eq(v)
      end
    end

    it 'sets tcp values to etcd' do
      container.env_hash['KONTENA_LB_MODE'] = 'tcp'
      storage = {}
      allow(etcd).to receive(:set) do |key, value|
        storage[key] = value[:value]
      end
      subject.ensure_config(container)
      expected_values = {
        "#{etcd_prefix}/lb/tcp-services/test-api/balance" => 'roundrobin'
      }
      expected_values.each do |k, v|
        expect(storage[k]).to eq(v)
      end
    end

    it 'sets custom virtual_path' do
      container.env_hash['KONTENA_LB_VIRTUAL_PATH'] = '/virtual'
      expect(etcd).to receive(:set).
        with("#{etcd_prefix}/lb/services/test-api/virtual_path", {value: '/virtual'})
      subject.ensure_config(container)
    end

    it 'sets custom virtual_hosts' do
      container.env_hash['KONTENA_LB_VIRTUAL_HOSTS'] = 'www.domain.com'
      expect(etcd).to receive(:set).
        with("#{etcd_prefix}/lb/services/test-api/virtual_hosts", {value: 'www.domain.com'})
      subject.ensure_config(container)
    end

    it 'removes tcp-services' do
      expect(subject).to receive(:rmdir).
        with("#{etcd_prefix}/lb/tcp-services/test-api")
      subject.ensure_config(container)
    end

    it 'removes services if mode is tcp' do
      container.env_hash['KONTENA_LB_MODE'] = 'tcp'
      expect(subject).to receive(:rmdir).
        with("#{etcd_prefix}/lb/services/test-api")
      subject.ensure_config(container)
    end
  end

  describe '#remove_config' do
    it 'removes http config from etcd' do
      expect(subject).to receive(:rmdir).
        with("#{etcd_prefix}/lb/services/test-api")
      subject.remove_config(container)
    end

    it 'removes tcp config from etcd' do
      container.env_hash['KONTENA_LB_MODE'] = 'tcp'
      expect(subject).to receive(:rmdir).
        with("#{etcd_prefix}/lb/tcp-services/test-api")
      subject.remove_config(container)
    end
  end
end

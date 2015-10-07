require_relative '../spec_helper'

describe LoadBalancerConfigurer do
  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  let(:node) { HostNode.create!(node_id: SecureRandom.uuid) }
  let(:grid) { Grid.create!(name: 'test-grid') }
  let(:client) { spy(:client) }
  let(:balanced_service) { GridService.create!(
      image_name: 'nginx:latest', name: 'web', grid: grid,
      env: [
        'KONTENA_LB_INTERNAL_PORT=80',
        'KONTENA_LB_MODE=http',
        'KONTENA_LB_BALANCE=source',
        'KONTENA_LB_VIRTUAL_HOSTS=www.kontena.io,kontena.io'
      ]
    )
  }
  let(:load_balancer) { GridService.create!(image_name: 'kontena/lb:latest', name: 'lb', grid: grid) }
  let(:subject) { described_class.new(client, load_balancer, balanced_service).wrapped_object }

  describe '#set' do
    it 'sets value to key' do
      expect(client).to receive(:request).with('/etcd/set', '/foo', {value: 'bar'})
      subject.set('/foo', 'bar')
    end

    it 'unsets key if value is nil' do
      expect(subject).to receive(:unset).with('/foo')
      subject.set('/foo', nil)
    end
  end

  describe '#unset' do
    it 'sends delete request to etcd' do
      expect(client).to receive(:request).with('/etcd/delete', '/foo', {})
      subject.unset('/foo')
    end
  end

  describe '#configure' do
    before(:each) do
      allow(subject).to receive(:set)
    end

    context 'http' do
      it 'sets balance to etcd' do
        expect(subject).to receive(:set).with(/\/lb\/services\/web\/balance/, 'source').once
        subject.configure
      end

      it 'sets virtual hosts to etcd' do
        expect(subject).to receive(:set).with(/\/lb\/services\/web\/virtual_hosts/, 'www.kontena.io,kontena.io').once
        subject.configure
      end
    end

    context 'tcp' do
      before(:each) do
        balanced_service.env = [
          'KONTENA_LB_EXTERNAL_PORT=80',
          'KONTENA_LB_INTERNAL_PORT=8080',
          'KONTENA_LB_MODE=tcp',
          'KONTENA_LB_BALANCE=roundrobin'
        ]
      end

      it 'sets external_port to etcd' do
        expect(subject).to receive(:set).with(/\/lb\/tcp-services\/web\/external_port/, '80').once
        subject.configure
      end

      it 'sets balance to etcd' do
        expect(subject).to receive(:set).with(/\/lb\/tcp-services\/web\/balance/, 'roundrobin').once
        subject.configure
      end
    end
  end
end

require_relative '../../../spec_helper'

describe Kontena::Rpc::ServicePodsApi do

  let(:data) do
    {
      'service_name' => 'redis',
      'instance_number' => 2,
      'deploy_rev' => Time.now.utc.to_s,
      'updated_at' => Time.now.utc.to_s,
      'labels' => {
        'io.kontena.service.name' => 'redis-cache',
        'io.kontena.container.overlay_cidr' => '10.81.23.2/19'
      },
      'stateful' => true,
      'image_name' => 'redis:3.0',
      'user' => nil,
      'cmd' => nil,
      'entrypoint' => nil,
      'memory' => nil,
      'memory_swap' => nil,
      'cpu_shares' => nil,
      'privileged' => false,
      'cap_add' => nil,
      'cap_drop' => nil,
      'devices' => [],
      'ports' => [],
      'env' => [
        'KONTENA_SERVICE_NAME=redis-cache'
      ],
      'volumes' => nil,
      'volumes_from' => nil,
      'net' => 'bridge',
      'log_driver' => nil
    }
  end

  describe '#create' do
    it 'calls service pod creator' do
      expect(Kontena::ServicePods::Creator).to receive(:perform_async)
      subject.create(data)
    end
  end

  describe '#start' do
    it 'calls service pod starter' do
      expect(Kontena::ServicePods::Starter).to receive(:perform_async)
      subject.start('test-1')
    end
  end

  describe '#stop' do
    it 'calls service pod stopper' do
      expect(Kontena::ServicePods::Stopper).to receive(:perform_async)
      subject.stop('test-1')
    end
  end

  describe '#restart' do
    it 'calls service pod restarter' do
      expect(Kontena::ServicePods::Restarter).to receive(:perform_async)
      subject.restart('test-1')
    end
  end

  describe '#start' do

  end
end

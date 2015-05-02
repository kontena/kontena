require_relative '../../spec_helper'

describe Rpc::DnsApi do

  let(:grid) { Grid.create! }
  let(:service) { GridService.create!(grid: grid, name: 'redis', image_name: 'redis:2.8') }
  let(:subject) { described_class.new(grid) }

  def create_container(service, i)
    service.containers.create!(
        grid: grid,
        container_id: "container_#{i}",
        name: "redis-#{i}",
        image: 'redis:2.8',
        network_settings: {ip_address: "192.168.11.#{i}"}
    )
  end

  describe '#record' do
    it 'returns empty array when match is not found' do
      expect(subject.record('foo')).to eq([])
    end

    it 'returns service container ip when container name is given' do
      create_container(service, 1)
      expect(subject.record('redis-1')).to eq(['192.168.11.1'])
    end

    it 'returns all service container ips when service name is given' do
      2.times do |i|
        create_container(service, i + 1)
      end
      expect(subject.record('redis').sort).to eq(['192.168.11.1', '192.168.11.2'])
    end
  end
end
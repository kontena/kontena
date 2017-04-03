
describe Metrics do
  let! :redis_service do
    grid = Grid.create!(name: 'terminal-a')

    grid.grid_services.create!(
      name: 'redis',
      image_name: 'redis:2.8',
      stateful: true,
      env: ['FOO=BAR']
    )
  end

  let! :containers do
    container1 = redis_service.containers.create!(name: 'redis-1', container_id: 'aaa')
    container1.container_stats.create!({
      memory: { 'usage' => 50 },
      cpu: { 'usage_pct' => 100 },
      network: {
        internal: {
          'interfaces' => ['ethwe'], 'rx_bytes' => 50, 'rx_bytes_per_second' => 50, 'tx_bytes' => 50, 'tx_bytes_per_second'=>50
        },
        external: {
          'interfaces' => ['eth0'], 'rx_bytes' => 50, 'rx_bytes_per_second' => 50, 'tx_bytes' => 50, 'tx_bytes_per_second'=>50
        }
      },
      spec: {
        'memory' => { 'limit' => 50},
        'cpu' => { 'limit' => 50, 'mask' => '0-1' }
      }
    })

    container2 = redis_service.containers.create!(name: 'redis-2', container_id: 'bbb')
    container2.container_stats.create!({
      memory: { 'usage' => 100 },
      cpu: { 'usage_pct' => 50 },
      network: {
        internal: {
          'interfaces' => ['ethwe'], 'rx_bytes' => 50, 'rx_bytes_per_second' => 50, 'tx_bytes' => 50, 'tx_bytes_per_second'=>50
        },
        external: {
          'interfaces' => ['eth0'], 'rx_bytes' => 50, 'rx_bytes_per_second' => 50, 'tx_bytes' => 50, 'tx_bytes_per_second'=>50
        }
      },
      spec: {
        'memory' => { 'limit' => 50},
        'cpu' => { 'limit' => 50, 'mask' => '0-1' }
      }
    })

    container3 = redis_service.containers.create!(name: 'redis-3', container_id: 'ccc')
    container3.container_stats.create!({
      memory: { 'usage' => 50 },
      cpu: { 'usage_pct' => 50 },
      network: {
        internal: {
          'interfaces' => ['ethwe'], 'rx_bytes' => 100, 'rx_bytes_per_second' => 50, 'tx_bytes' => 50, 'tx_bytes_per_second'=>50
        },
        external: {
          'interfaces' => ['eth0'], 'rx_bytes' => 50, 'rx_bytes_per_second' => 50, 'tx_bytes' => 50, 'tx_bytes_per_second'=>50
        }
      },
      spec: {
        'memory' => { 'limit' => 50},
        'cpu' => { 'limit' => 50, 'mask' => '0-1' }
      }
    })

    container4 = redis_service.containers.create!(name: 'redis-4', container_id: 'ddd')
    container4.container_stats.create!({
      memory: { 'usage' => 50 },
      cpu: { 'usage_pct' => 50 },
      network: {
        internal: {
          'interfaces' => ['ethwe'], 'rx_bytes' => 50, 'rx_bytes_per_second' => 50, 'tx_bytes' => 50, 'tx_bytes_per_second'=>50
        },
        external: {
          'interfaces' => ['eth0'], 'rx_bytes' => 50, 'rx_bytes_per_second' => 50, 'tx_bytes' => 100, 'tx_bytes_per_second'=>50
        }
      },
      spec: {
        'memory' => { 'limit' => 50},
        'cpu' => { 'limit' => 50, 'mask' => '0-1' }
      }
    })

    [container1, container2, container3, container4]
  end

  describe '#get_container_stats' do
    it 'returns all stats by default' do
      redis_service
      containers

      results = Metrics.get_container_stats(redis_service.containers, nil, nil)
      expect(results.size).to eq 4
    end

    it 'can limit number of records' do
      redis_service
      containers

      results = Metrics.get_container_stats(redis_service.containers, nil, 2)
      expect(results.size).to eq 2
    end

    it 'can sort by cpu' do
      redis_service
      containers

      results = Metrics.get_container_stats(redis_service.containers, :cpu, 1)
      expect(results.size).to eq 1
      expect(results[0][:container]).to eq containers[0]
    end

    it 'can sort by memory' do
      redis_service
      containers

      results = Metrics.get_container_stats(redis_service.containers, :memory, 1)
      expect(results.size).to eq 1
      expect(results[0][:container]).to eq containers[1]
    end

    it 'can sort by rx_bytes' do
      redis_service
      containers

      results = Metrics.get_container_stats(redis_service.containers, :rx_bytes, 1)
      expect(results.size).to eq 1
      expect(results[0][:container]).to eq containers[2]
    end

    it 'can sort by tx_bytes' do
      redis_service
      containers

      results = Metrics.get_container_stats(redis_service.containers, :tx_bytes, 1)
      expect(results.size).to eq 1
      expect(results[0][:container]).to eq containers[3]
    end
  end
end

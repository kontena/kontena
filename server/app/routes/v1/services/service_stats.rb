V1::ServicesApi.route('service_stats') do |r|

  # GET /v1/services/:grid_name/:service_name/stats
  r.get do
    r.is do
      containers = @grid_service.containers.asc(:name)
      @stats = containers.map do |container|
        stat = container.container_stats.last
        if stat
          sum = ContainerStat.collection.aggregate([
          {
            '$match' => {
              'grid_service_id' => @grid_service.id
            }
          },
          {
            '$group' => {
              '_id' => {name: '$name'},
              'rx_bytes' => { '$max' => '$network.rx_bytes'},
              'tx_bytes' => { '$max' => '$network.tx_bytes'}
            }
          }])
          if stat.spec['memory']['limit'] == 1.8446744073709552e+19
            stat.spec['memory']['limit'] = container.host_node.mem_total
          end
          if sum[0]
            stat.network['rx_bytes'] = sum[0]['rx_bytes']
            stat.network['tx_bytes'] = sum[0]['tx_bytes']
          end
        end
        {
            container: container,
            stats: stat
        }
      end
      render('grid_services/stats')
    end
  end
end

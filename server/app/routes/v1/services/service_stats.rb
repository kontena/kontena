V1::ServicesApi.route('service_stats') do |r|

  # GET /v1/services/:grid_name/:service_name/stats
  r.get do
    r.is do
      containers = @grid_service.containers.asc(:name)
      @stats = containers.map do |container|
        stat = container.container_stats.last
        {
            container: container,
            stats: stat
        }
      end
      render('grid_services/stats')
    end
  end
end

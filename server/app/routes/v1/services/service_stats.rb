V1::ServicesApi.route('service_stats') do |r|

  # GET /v1/services/:grid_name/:service_name/stats
  r.get do
    r.is do
      sort = r.params["sort"] ? r.params["sort"] : "cpu"

      @stats = Metrics.get_container_stats(@grid_service.containers, sort.to_sym)
      render('stats/stats')
    end
  end
end

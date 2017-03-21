V1::ServicesApi.route('service_stats') do |r|

  # GET /v1/services/:grid_name/:service_name/stats
  r.get do
    r.is do
      network_iface = r.params["iface"] ? r.params["iface"] : "eth0"
      sort = r.params["sort"] ? r.params["sort"] : "cpu"

      @stats = Metrics.get_container_stats(@grid_service.containers, network_iface, sort.to_sym)
      render('grid_services/stats')
    end
  end
end

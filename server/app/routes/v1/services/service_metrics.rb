V1::ServicesApi.route('service_metrics') do |r|

  # GET /v1/services/:grid_name/:service_name/metrics
  r.get do
    r.is do
      @to = (r.params["to"] ? Time.parse(r.params["to"]) : Time.now).utc
      @from = (r.params["from"] ? Time.parse(r.params["from"]) : (@to - 1.hour)).utc
      @network_iface = r.params["iface"] ? r.params["iface"] : "eth0"
      @container_stats = ContainerStat.get_aggregate_stats_for_service(@grid_service.id, @from, @to, @network_iface)

      render('grid_services/metrics')
    end
  end
end

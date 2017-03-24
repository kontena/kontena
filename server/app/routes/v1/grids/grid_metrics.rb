V1::GridsApi.route('grid_metrics') do |r|

  # GET /v1/grids/:id/metrics
  r.get do
    r.is do
      @to = (r.params["to"] ? Time.parse(r.params["to"]) : Time.now).utc
      @from = (r.params["from"] ? Time.parse(r.params["from"]) : (@to - 1.hour)).utc
      
      @metrics = HostNodeStat.get_aggregate_stats_for_grid(@grid.id, @from, @to)
      render('stats/metrics')
    end
  end
end

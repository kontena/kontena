V1::GridsApi.route('grid_container_logs') do |r|

  # GET /v1/grids/:name/container_logs
  r.get do
    r.is do
      scope = @grid.container_logs
      limit = (r['limit'] || 100).to_i

      scope = scope.where(name: r['container']) unless r['container'].nil?
      scope = scope.where(:$text => {:$search => r['search']}) unless r['search'].nil?
      scope = scope.where(:id.gt => r['from'] ) unless r['from'].nil?

      @logs = scope.order(:_id => -1).limit(limit).to_a.reverse
      render('container_logs/index')
    end
  end
end

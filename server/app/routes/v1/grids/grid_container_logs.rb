V1::GridsApi.route('grid_container_logs') do |r|

  # GET /v1/grids/:name/container_logs
  r.get do
    r.is do
      scope = @grid.container_logs
      nodes = nil
      services = nil
      container_names = nil
      limit = (r['limit'] || 100).to_i
      follow = r['follow'] || false
      from = r['from']
      since = r['since']

      unless r['containers'].nil?
        container_names = r['containers'].split(',')
      end

      unless r['nodes'].nil?
        nodes = r['nodes'].split(',').map do |name|
          @grid.host_nodes.find_by(name: name).try(:id)
        end.delete_if{|n| n.nil?}
      end
      unless r['services'].nil?
        services = r['services'].split(',').map do |service|
          @grid.grid_services.find_by(name: service).try(:id)
        end.delete_if{|s| s.nil?}
      end

      if follow
        first_run = true
        stream(loop: true) do |out|
          scope = @grid.container_logs
          scope = scope.where(grid_service_id: {:$in => services}) if services
          scope = scope.where(host_node_id: {:$in => nodes}) if nodes
          scope = scope.where(name: {:$in => container_names}) if container_names
          scope = scope.where(:id.gt => from) unless from.nil?
          if !since.nil? && from.nil?
            since = DateTime.parse(since) rescue nil
            scope = scope.where(:created_at.gt => since)
          end
          scope = scope.order(:_id => -1)
          if first_run
            logs = scope.limit(limit).to_a.reverse
          else
            logs = scope.to_a.reverse
          end
          logs.each do |log|
            out << render('container_logs/_container_log', {locals: {log: log}})
          end
          first_run = false
          sleep 0.5 if logs.size == 0
          from = logs.last.id if logs.last
        end
      else
        scope = scope.where(grid_service_id: {:$in => services}) if services
        scope = scope.where(host_node_id: {:$in => nodes}) if nodes
        scope = scope.where(name: {:$in => container_names}) if container_names
        scope = scope.where(:id.gt => from ) unless from.nil?
        if !since.nil? && from.nil?
          since = DateTime.parse(since) rescue nil
          scope = scope.where(:created_at.gt => since)
        end
        @logs = scope.order(:_id => -1).limit(limit).to_a.reverse
        render('container_logs/index')
      end
    end
  end
end

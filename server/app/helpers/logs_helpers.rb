module LogsHelpers
  # @param r [Roda::RodaRequest]
  # @param scope [Mongoid::CriteriaMongoid::Criteria] of ContainerLog
  def render_container_logs(r, scope)
    follow = r['follow']
    from = r['from']
    limit = (r['limit'] || 100).to_i

    if !r['since'].nil? && from.nil?
      since = DateTime.parse(r['since']) rescue nil
      scope = scope.where(:created_at.gt => since)
    end

    if follow
      stream(loop: true) do |out|
        if from
          # all items following a specific item, without limit
          logs  = scope.where(:id.gt => from).order(:id => 1).to_a
        else
          # limit most recent logs
          logs = scope.order(:id => -1).limit(limit).to_a.reverse
        end

        if !logs.empty?
          logs.each do |log|
            out << render('container_logs/_container_log', locals: {log: log})
          end
          from = logs.last.id
        else
          # idle keepalive, trigger write errors on timeout
          out << ' '

          sleep 0.5
        end
      end
    else
      scope = scope.where(:id.gt => from) unless from.nil?

      # limit most recent logs
      logs = scope.order(:_id => -1).limit(limit).to_a.reverse

      render('container_logs/index', locals: {logs: logs})
    end
  end
end

module Kontena::Cli::Grids
  class LogsCommand < Kontena::Command
    include Kontena::Cli::Common

    option ["-t", "--tail"], :flag, "Tail (follow) logs", default: false
    option "--lines", "LINES", "Number of lines to show from the end of the logs"
    option "--since", "SINCE", "Show logs since given timestamp"
    option "--node", "NODE", "Filter by node name", multivalued: true
    option "--service", "SERVICE", "Filter by service name", multivalued: true
    option ["-c", "--container"], "CONTAINER", "Filter by container", multivalued: true

    def execute
      require_api_url
      token = require_token

      query_params = {}
      query_params[:nodes] = node_list.join(",") unless node_list.empty?
      query_params[:services] = service_list.join(",") unless service_list.empty?
      query_params[:containers] = container_list.join(",") unless container_list.empty?
      query_params[:limit] = lines if lines
      query_params[:since] = since if since

      if tail?
        @buffer = ''
        query_params[:follow] = 1
        stream_logs(token, query_params)
      else
        list_logs(token, query_params)
      end
    end

    def list_logs(token, query_params)
      result = client(token).get("grids/#{current_grid}/container_logs", query_params)
      result['logs'].each do |log|
        color = color_for_container(log['name'])
        prefix = ""
        prefix << "#{log['created_at']} "
        prefix << "#{log['name']}:"
        prefix = prefix.colorize(color)
        puts "#{prefix} #{log['data']}"
      end
    end

    def stream_logs(token, query_params)
      streamer = lambda do |chunk, remaining_bytes, total_bytes|
        begin
          unless @buffer.empty?
            chunk = @buffer + chunk
          end
          unless chunk.empty?
            log = JSON.parse(chunk)
          end
          @buffer = ''
        rescue => exc
          @buffer << chunk
        end
        if log
          @last_seen = log['id']
          color = color_for_container(log['name'])
          puts "#{log['name'].colorize(color)} | #{log['data']}"
        end
      end

      begin
        if @last_seen
          query_params[:from] = @last_seen
        end
        result = client(token).get_stream(
          "grids/#{current_grid}/container_logs", streamer, query_params
        )
      rescue => exc
        if exc.cause.is_a?(EOFError) # Excon wraps the EOFerror into SockerError
          retry
        end
      end

    end

    def color_for_container(container_id)
      color_maps[container_id] = colors.shift unless color_maps[container_id]
      color_maps[container_id].to_sym
    end

    def color_maps
      @color_maps ||= {}
    end

    def colors
      if(@colors.nil? || @colors.size == 0)
        @colors = [:green, :yellow, :magenta, :cyan, :red,
          :light_green, :light_yellow, :ligh_magenta, :light_cyan, :light_red]
      end
      @colors
    end
  end
end

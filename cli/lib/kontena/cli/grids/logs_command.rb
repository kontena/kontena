module Kontena::Cli::Grids
  class LogsCommand < Clamp::Command
    include Kontena::Cli::Common

    option ["-f", "--follow"], :flag, "Follow (tail) logs", default: false
    option ["-s", "--search"], "SEARCH", "Search from logs"
    option "--lines", "LINES", "Number of lines to show from the end of the logs"
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
      query_params[:search] = search if search
      query_params[:limit] = lines if lines


      if follow?
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
        puts "#{log['name'].colorize(color)} | #{log['data']}"
      end
    end

    def stream_logs(token, query_params)
      streamer = lambda do |chunk, remaining_bytes, total_bytes|
        log = JSON.parse(chunk)
        if log
          color = color_for_container(log['name'])
          puts "#{log['name'].colorize(color)} | #{log['data']}"
        end
      end

      result = client(token).get_stream(
        "grids/#{current_grid}/container_logs", streamer, query_params
      )
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

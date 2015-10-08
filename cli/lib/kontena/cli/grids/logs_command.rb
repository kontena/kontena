module Kontena::Cli::Grids
  class LogsCommand < Clamp::Command
    include Kontena::Cli::Common

    option ["-f", "--follow"], :flag, "Follow (tail) logs", default: false
    option ["-s", "--search"], "SEARCH", "Search from logs"
    option ["-c", "--container"], "CONTAINER", "Show only specified container logs"

    def execute
      require_api_url
      token = require_token
      last_id = nil
      loop do
        query_params = []
        query_params << "from=#{last_id}" unless last_id.nil?
        query_params << "search=#{search}" if search
        query_params << "container=#{container}" if container

        result = client(token).get("grids/#{current_grid}/container_logs?#{query_params.join('&')}")
        result['logs'].each do |log|
          color = color_for_container(log['name'])
          puts "#{log['name'].colorize(color)} | #{log['data']}"
          last_id = log['id']
        end
        break unless follow?
        sleep(2)
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

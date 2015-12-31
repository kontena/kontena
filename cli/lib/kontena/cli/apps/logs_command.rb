require_relative 'common'

module Kontena::Cli::Apps
  class LogsCommand < Clamp::Command
    include Kontena::Cli::Common
    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'
    option ["-s", "--search"], "SEARCH", "Search from logs"
    option ["-t", "--follow"], :flag, "Follow (tail) logs", default: false
    parameter "[SERVICE] ...", "Show only specified service logs"

    attr_reader :services, :service_prefix

    def execute
      require_config_file(filename)

      @service_prefix = project_name || current_dir
      @services = load_services(filename, service_list, service_prefix)
      if services.size > 0
        show_logs(services)
      elsif !service_list.empty?
        puts "No such service: #{service_list.join(', ')}".colorize(:red)
      end

    end

    def show_logs(services)
      last_id = nil
      loop do
        query_params = []
        query_params << "from=#{last_id}" unless last_id.nil?
        query_params << "search=#{search}" if search
        logs = []
        services.each do |service_name, opts|
          service = get_service(token, prefixed_name(service_name)) rescue false
          result = client(token).get("services/#{service['id']}/container_logs?#{query_params.join('&')}") if service
          logs = logs + result['logs'] if result && result['logs']
        end
        logs.sort!{|x,y| DateTime.parse(x['created_at']) <=> DateTime.parse(y['created_at'])}
        logs.each do |log|
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
        @colors = [:green, :magenta, :yellow, :cyan, :red,
                   :light_green, :light_yellow, :ligh_magenta, :light_cyan, :light_red]
      end
      @colors
    end
  end
end

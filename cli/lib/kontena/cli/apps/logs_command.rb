require_relative 'common'

module Kontena::Cli::Apps
  class LogsCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'
    option ["-l", "--lines"], "LINES", "How many lines to show", default: '100'
    option "--since", "SINCE", "Show logs since given timestamp"
    option ["-t", "--tail"], :flag, "Tail (follow) logs", default: false
    parameter "[SERVICE] ...", "Show only specified service logs"

    attr_reader :services

    def execute
      require_config_file(filename)

      @services = services_from_yaml(filename, service_list, service_prefix)
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
        query_params << "limit=#{lines}"
        query_params << "since=#{since}" if !since.nil? && last_id.nil?
        logs = []
        services.each do |service_name, opts|
          service = get_service(token, prefixed_name(service_name)) rescue false
          result = client(token).get("services/#{service['id']}/container_logs?#{query_params.join('&')}") if service
          logs = logs + result['logs'] if result && result['logs']
        end
        logs.sort!{|x,y| DateTime.parse(x['created_at']) <=> DateTime.parse(y['created_at'])}
        logs.each do |log|
          color = color_for_container(log['name'])
          prefix = "#{log['created_at']} #{log['name']}:".colorize(color)
          puts "#{prefix} #{log['data']}"
          last_id = log['id']
        end
        break unless tail?
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

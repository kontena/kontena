require_relative 'common'

module Kontena::Cli::Apps
  class LogsCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'
    option ["-l", "--lines"], "LINES", "How many lines to show", default: 100 do |s|
      Integer(s)
    end
    option "--since", "SINCE", "Show logs since given timestamp"
    option ["-t", "--tail"], :flag, "Tail (follow) logs", default: false
    parameter "[SERVICE] ...", "Show only specified service logs"

    attr_reader :services

    def execute
      require_config_file(filename)

      @services = services_from_yaml(filename, service_list, service_prefix)
      if services.size > 0
        if tail?
          tail_logs(services)
        else
          show_logs(services)
        end
      elsif !service_list.empty?
        puts "No such service: #{service_list.join(', ')}".colorize(:red)
      end
    end

    def tail_logs(services)
      services_from = { }

      loop do
        get_logs(services, services_from).each do |log|
          show_log(log)
          services_from[log[:service]] = log['id']
        end
        sleep(2)
      end
    end

    def show_logs(services)
      get_logs(services).each do |log|
        show_log(log)
      end
    end

    def get_logs(services, services_from = nil)
      logs = []
      services.each do |service_name, opts|
        service = get_service(token, prefixed_name(service_name)) rescue false

        if service
          from = services_from[service['id']] if services_from
          query_params = { }
          query_params['limit'] = lines if from.nil?
          query_params['since'] = since if !since.nil? && from.nil?
          query_params['from'] = from if !from.nil?

          result = client(token).get("services/#{service['id']}/container_logs", query_params)

          if result && result['logs']
            result['logs'].each{|log| log[:service] = service['id']}
            logs = logs + result['logs']
          end
        end
      end
      logs.sort!{|x,y| DateTime.parse(x['created_at']) <=> DateTime.parse(y['created_at'])}
    end

    def show_log(log)
      color = color_for_container(log['name'])
      prefix = "#{log['created_at']} #{log['name']}:".colorize(color)
      puts "#{prefix} #{log['data']}"
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

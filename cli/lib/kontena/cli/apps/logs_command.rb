require_relative 'common'
require_relative '../helpers/log_helper'

module Kontena::Cli::Apps
  class LogsCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::LogHelper

    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'
    option ["-l", "--lines"], "LINES", "How many lines to show", default: '100'
    option "--since", "SINCE", "Show logs since given timestamp"
    option ["-t", "--tail"], :flag, "Tail (follow) logs", default: false
    parameter "[SERVICE] ...", "Show only specified service logs"

    def execute
      require_config_file(filename)

      services = services_from_yaml(filename, service_list, service_prefix)

      if services.empty? && !service_list.empty?
        signal_error "No such service: #{service_list.join(', ')}"
      elsif services.empty?
        signal_error "No services for application"
      end

      query_services = services.map{|service_name, opts| prefixed_name(service_name)}.join ','
      query_params = {
        services: query_services,
        limit: lines,
      }
      query_params[:since] = since if since

      if tail?
        tail_logs(services, query_params)
      else
        show_logs(services, query_params)
      end
    end

    def tail_logs(services, query_params)
      stream_logs("grids/#{current_grid}/container_logs", query_params) do |log|
        show_log(log)
      end
    end

    def show_logs(services, query_params)
      result = client(token).get("grids/#{current_grid}/container_logs", query_params)
      result['logs'].each do |log|
        show_log(log)
      end
    end

    def show_log(log)
      color = color_for_container(log['name'])
      prefix = "#{log['created_at']} #{log['name']}:".colorize(color)
      puts "#{prefix} #{log['data']}"
    end
  end
end

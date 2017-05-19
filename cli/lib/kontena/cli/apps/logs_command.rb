require_relative 'common'
require_relative '../helpers/log_helper'

module Kontena::Cli::Apps
  class LogsCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Helpers::LogHelper

    include Common

    option ['-f', '--file'], 'YAML_FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'
    parameter "[SERVICE] ...", "Show only specified service logs", completion: :yaml_services

    def execute
      require_config_file(filename)

      services = services_from_yaml(filename, service_list, service_prefix, true)

      if services.empty? && !service_list.empty?
        signal_error "No such service: #{service_list.join(', ')}"
      elsif services.empty?
        signal_error "No services for application"
      end

      query_services = services.map{|service_name, opts| prefixed_name(service_name)}.join ','
      query_params = {
        services: query_services,
      }

      show_logs("grids/#{current_grid}/container_logs", query_params) do |log|
        show_log(log)
      end
    end
  end
end

require_relative 'common'

module Kontena::Cli::Apps
  class ShowCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    option ['-f', '--file'], 'YAML_FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'

    parameter "SERVICE", "Service to show", completion: :yaml_services

    attr_reader :services

    def execute
      require_config_file(filename)
      token = require_token
      show_service(token, prefixed_name(service))
      show_service_instances(token, prefixed_name(service))
    end
  end
end

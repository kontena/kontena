require_relative 'common'

module Kontena::Cli::Apps
  class ScaleCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'

    parameter "SERVICE", "Service to show"
    parameter "INSTANCES", "Scales service to given number of instances"

    attr_reader :services

    def execute
      require_config_file(filename)
      yml_service = services_from_yaml(filename, [service], service_prefix)
      if yml_service[service]
        options = yml_service[service]
        abort("Service has already instances defined in #{filename}. Please update #{filename} and deploy service instead") if options['container_count']
        scale_service(require_token, prefixed_name(service), instances)
      else
        abort("Service not found")
      end
    end


  end
end

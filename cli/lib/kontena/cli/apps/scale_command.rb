require_relative 'common'

module Kontena::Cli::Apps
  class ScaleCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    option ['-f', '--file'], 'YAML_FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'

    parameter "SERVICE", "Service to show", completion: :yaml_services
    parameter "INSTANCES", "Scales service to given number of instances"

    attr_reader :services

    def execute
      require_config_file(filename)
      yml_service = services_from_yaml(filename, [service], service_prefix, true)
      if yml_service[service]
        options = yml_service[service]
        exit_with_error("Service has already instances defined in #{filename}. Please update #{filename} and deploy service instead") if options['instances']
        spinner "Scaling #{service.colorize(:cyan)} " do
          deployment = scale_service(require_token, prefixed_name(service), instances)
          wait_for_deploy_to_finish(token, deployment)
        end

      else
        exit_with_error("Service not found")
      end
    end
  end
end

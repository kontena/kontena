require_relative 'common'
require_relative 'docker_helper'

module Kontena::Cli::Apps
  class BuildCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common
    include DockerHelper

    option ['-p', '--project-name'], 'NAME', 'Specify an alternate project name (default: directory name)'
    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['--no-cache'], :flag, 'Do not use cache when building the image', default: false
    parameter "[SERVICE] ...", "Services to build"

    attr_reader :services

    def execute
      require_config_file(filename)
      @services = services_from_yaml(filename, service_list, service_prefix)
      if services.none?{ |name, service| service['build'] }
        abort 'Not found any service with build option'.colorize(:red)
      end
      process_docker_images(services, true, no_cache?)
    end
  end
end

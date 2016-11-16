require_relative 'common'

module Kontena::Cli::Stacks
  class BuildCommand < Clamp::Command
    include Kontena::Cli::Common
    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena compose file', attribute_name: :filename, default: 'kontena.yml'
    option ['--no-cache'], :flag, 'Do not use cache when building the image', default: false
    option ['--no-push'], :flag, 'Push images to registry', default: false
    parameter "[SERVICE] ...", "Services to build"

    attr_reader :services

    def execute
      require_config_file(filename)
      @services = services_from_yaml(filename, service_list, service_prefix)
      if services.none?{ |name, service| service['build'] }
        abort 'Not found any service with build option'.colorize(:red)
      end
      build_docker_images(services, true, no_cache?)
      push_docker_images(services) unless no_push?
    end
  end
end

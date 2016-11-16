require_relative '../apps/yaml/reader'
require_relative '../apps/common'
require_relative '../apps/docker_helper'

module Kontena::Cli::Stacks
  module Common
    include Kontena::Cli::Apps::Common
    include Kontena::Cli::Apps::DockerHelper

    def service_prefix
      @service_prefix ||= project_name_from_yaml(filename)
    end

    def stack_from_yaml(filename)
      set_env_variables(service_prefix, current_grid)
      outcome = read_yaml(filename)
      if outcome[:name].nil?
        exit_with_error "Stack MUST have name in YAML! Aborting."
      end
      hint_on_validation_notifications(outcome[:notifications]) if outcome[:notifications].size > 0
      abort_on_validation_errors(outcome[:errors]) if outcome[:errors].size > 0
      kontena_services = generate_services(outcome[:services], outcome[:version])
      # services now as hash, needs to be array in stacks API
      services = []
      kontena_services.each do |name, service|
        service['name'] = name
        services << service
      end
      stack = {
        'name' => outcome[:name],
        'services' => services
      }
      stack
    end


    # @param [Hash] services
    # @param [Boolean] force_build
    # @param [Boolean] no_cache
    def build_docker_images(services, force_build = false, no_cache = false)
      services.each do |name, service|
        if service['build'] && (!image_exist?(service['image']) || force_build)
          dockerfile = service['build']['dockerfile'] || 'Dockerfile'
          abort("'#{service['image']}' is not valid Docker image name") unless validate_image_name(service['image'])
          abort("'#{service['build']['context']}' does not have #{dockerfile}") unless dockerfile_exist?(service['build']['context'], dockerfile)
          if service['hooks'] && service['hooks']['pre_build']
            puts "Running pre_build hook".colorize(:cyan)
            run_pre_build_hook(service['hooks']['pre_build'])
          end
          puts "Building image #{service['image'].colorize(:cyan)}"
          build_docker_image(service, no_cache)
        end
      end
    end

    # @param [Hash] services
    def process_docker_images(services)
      services.each do |name, service|
        if service['build'] && image_exist?(service['image'])
          puts "Pushing image #{service['image'].colorize(:cyan)} to registry"
          push_docker_image(service['image'])
        end
      end
    end
  end
end

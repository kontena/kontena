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
  end
end

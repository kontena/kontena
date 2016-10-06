require_relative 'services_helper'

module Kontena::Cli::Services
  class ScaleCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"
    parameter "INSTANCES", "Scales service to given number of instances"

    requires_current_master_token

    def execute
      spinner "Scaling #{name} " do
        scale_service(name, instances)
        wait_for_deploy_to_finish(parse_service_id(name))
      end
    end
  end
end

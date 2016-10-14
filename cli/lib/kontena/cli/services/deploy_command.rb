require_relative 'services_helper'

module Kontena::Cli::Services
  class DeployCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"
    option '--force-deploy', :flag, 'Force deploy even if service does not have any changes'

    requires_current_master_token

    def execute
      service_id = name
      data = {}
      data[:force] = true if force_deploy?
      spinner "Deploying service #{name.colorize(:cyan)} " do
        deploy_service(name, data)
        wait_for_deploy_to_finish(parse_service_id(name))
      end
    end
  end
end

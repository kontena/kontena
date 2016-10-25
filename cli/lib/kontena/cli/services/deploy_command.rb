require_relative 'services_helper'

module Kontena::Cli::Services
  class DeployCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"
    option '--force-deploy', :flag, 'Force deploy even if service does not have any changes'

    def execute
      require_api_url
      token = require_token
      service_id = name
      data = {}
      data[:force] = true if force_deploy?
      spinner "Deploying service #{name.colorize(:cyan)} " do
        deploy_service(token, name, data)
        wait_for_deploy_to_finish(token, parse_service_id(name))
      end
    end
  end
end

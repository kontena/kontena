require_relative 'services_helper'

module Kontena::Cli::Services
  class DeployCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"
    option '--force', :flag, 'Force deploy even if service does not have any changes'
    option '--force-deploy', :flag, '[DEPRECATED: use --force]'

    def execute
      require_api_url
      token = require_token
      service_id = name
      data = {}
      data[:force] = true if force? || force_deploy? # deprecated
      if force_deploy?
        warning "--force-deploy will deprecate in the future, use --force"
      end
      spinner "Deploying service #{name.colorize(:cyan)} " do
        deployment = deploy_service(token, name, data)
        wait_for_deploy_to_finish(token, deployment)
      end
    end
  end
end

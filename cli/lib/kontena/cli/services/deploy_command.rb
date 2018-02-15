require_relative 'services_helper'

module Kontena::Cli::Services
  class DeployCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"
    option '--[no-]wait', :flag, 'Do not wait for service deployment', default: true
    option '--force', :flag, 'Force deploy even if service does not have any changes'

    def execute
      require_api_url
      token = require_token
      service_id = name
      data = {}
      data[:force] = true if force?
      spinner "Deploying service #{pastel.cyan(name)} " do
        deployment = deploy_service(token, name, data)
        wait_for_deploy_to_finish(token, deployment) if wait?
      end
    end
  end
end

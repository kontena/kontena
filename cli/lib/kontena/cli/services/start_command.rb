require_relative 'services_helper'

module Kontena::Cli::Services
  class StartCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME ...", "Service name", attribute_name: :names
    option '--[no-]wait', :flag, 'Do not wait for service to start', default: true

    def execute
      require_api_url
      token = require_token
      names.each do |name|
        spinner "Starting service #{pastel.cyan(name)}" do
          deployment = start_service(token, name)
          wait_for_deploy_to_finish(token, deployment) if wait?
        end
      end
    end
  end
end

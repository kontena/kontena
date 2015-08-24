require_relative 'services_helper'

module Kontena::Cli::Services
  class DeployCommand < Clamp::Command
    include Kontena::Cli::Common
    include ServicesHelper

    parameter "NAME", "Service name"
    option '--strategy', 'STRATEGY', 'Define deploy strategy (ha / random)'
    option '--wait-for-port', 'WAIT_FOR_PORT', 'Wait for given container port to open before deploying next container'

    def execute
      require_api_url
      token = require_token
      service_id = name
      data = {}
      data[:strategy] = strategy if strategy
      data[:wait_for_port] = wait_for_port if wait_for_port
      deploy_service(token, service_id, data)
      show_service(token, service_id)
    end
  end
end

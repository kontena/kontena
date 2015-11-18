require_relative 'services_helper'

module Kontena::Cli::Services
  class DeployCommand < Clamp::Command
    include Kontena::Cli::Common
    include ServicesHelper

    parameter "NAME", "Service name"

    def execute
      require_api_url
      token = require_token
      service_id = name
      deploy_service(token, service_id, {})
    end
  end
end

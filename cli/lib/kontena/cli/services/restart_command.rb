require_relative 'services_helper'

module Kontena::Cli::Services
  class RestartCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"

    def execute
      require_api_url
      token = require_token
      restart_service(token, name)
    end
  end
end

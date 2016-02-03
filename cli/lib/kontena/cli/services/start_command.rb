require_relative 'services_helper'

module Kontena::Cli::Services
  class StartCommand < Clamp::Command
    include Kontena::Cli::Common
    include ServicesHelper

    parameter "NAME", "Service name"

    def execute
      require_api_url
      token = require_token
      start_service(token, name)
    end
  end
end

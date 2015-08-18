require_relative 'services_helper'

module Kontena::Cli::Services
  class StopCommand < Clamp::Command
    include Kontena::Cli::Common
    include ServicesHelper

    parameter "NAME", "Service name"

    def execute
      require_api_url
      token = require_token
      result = client(token).post("services/#{parse_service_id(name)}/stop", {})
    end
  end
end

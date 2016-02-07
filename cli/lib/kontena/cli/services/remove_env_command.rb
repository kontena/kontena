require_relative 'services_helper'

module Kontena::Cli::Services
  class RemoveEnvCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"
    parameter "ENV", "Environment variable name"

    def execute
      require_api_url
      token = require_token
      client(token).delete("services/#{parse_service_id(name)}/envs/#{env}")
    end
  end
end

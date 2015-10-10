require_relative 'services_helper'

module Kontena::Cli::Services
  class AddEnvCommand < Clamp::Command
    include Kontena::Cli::Common
    include ServicesHelper

    parameter "NAME", "Service name"
    parameter "ENV", "Environment variable"

    def execute
      require_api_url
      token = require_token
      data = {env: env}
      result = client(token).post("services/#{parse_service_id(name)}/envs", data)
    end
  end
end

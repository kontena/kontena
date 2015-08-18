require_relative 'services_helper'

module Kontena::Cli::Services
  class ScaleCommand < Clamp::Command
    include Kontena::Cli::Common
    include ServicesHelper

    parameter "NAME", "Service name"
    parameter "INSTANCES", "Scales service to given number of instances"
    option '--strategy', 'STRATEGY', 'Define deploy strategy (ha / random)'

    def execute
      token = require_token
      client(token).put("services/#{parse_service_id(name)}", {container_count: instances})
      opts = {}
      opts[:strategy] = strategy if strategy
      deploy_service(token, name, opts)
    end
  end
end

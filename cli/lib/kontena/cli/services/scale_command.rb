require_relative 'services_helper'

module Kontena::Cli::Services
  class ScaleCommand < Clamp::Command
    include Kontena::Cli::Common
    include ServicesHelper

    parameter "NAME", "Service name"
    parameter "INSTANCES", "Scales service to given number of instances"

    def execute
      token = require_token
      client(token).post("services/#{parse_service_id(name)}/scale", {instances: instances})
    end
  end
end

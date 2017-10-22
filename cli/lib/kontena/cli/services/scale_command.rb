require_relative 'services_helper'

module Kontena::Cli::Services
  class ScaleCommand < Kontena::Command
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"
    parameter "INSTANCES", "Scales service to given number of instances"

    def execute
      token = require_token
      spinner "Scaling #{pastel.cyan(name)} to #{instances} instances " do
        deployment = scale_service(token, name, instances)
        wait_for_deploy_to_finish(token, deployment)
      end
    end
  end
end

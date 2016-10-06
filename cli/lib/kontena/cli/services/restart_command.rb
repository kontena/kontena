require_relative 'services_helper'

module Kontena::Cli::Services
  class RestartCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"

    requires_current_master_token

    def execute
      spinner "Sending restart signal to service #{name.colorize(:cyan)} " do
        restart_service(name)
      end
    end
  end
end

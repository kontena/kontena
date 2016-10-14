require_relative 'services_helper'

module Kontena::Cli::Services
  class StopCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"

    requires_current_master_token

    def execute
      spinner "Sending stop signal to #{name.colorize(:cyan)} service " do
        stop_service(name)
      end
    end
  end
end

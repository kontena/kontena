require_relative 'services_helper'

module Kontena::Cli::Services
  class StartCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"

    requires_current_master_token

    def execute
      spinner "Sending start signal to #{name.colorize(:cyan)} service " do
        start_service(name)
      end
    end
  end
end

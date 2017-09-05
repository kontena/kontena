require_relative 'services_helper'

module Kontena::Cli::Services
  class StopCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"

    def execute
      require_api_url
      token = require_token
      spinner "Sending stop signal to #{pastel.cyan(name)} service " do
        stop_service(token, name)
      end
    end
  end
end

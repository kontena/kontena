require_relative 'services_helper'

module Kontena::Cli::Services
  class ShowCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"

    def execute
      require_api_url
      token = require_token

      show_service(token, name)
    end
  end
end

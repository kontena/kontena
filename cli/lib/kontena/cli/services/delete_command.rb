require_relative 'services_helper'

module Kontena::Cli::Services
  class DeleteCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"

    def execute
       puts "DEPRECATION WARNING: Support for 'kontena service delete' will be dropped. Use 'kontena service remove' instead.".colorize(:red)
      require_api_url
      token = require_token

      result = client(token).delete("services/#{parse_service_id(name)}")
    end
  end
end

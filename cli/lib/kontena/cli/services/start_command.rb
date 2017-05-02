require_relative 'services_helper'

module Kontena::Cli::Services
  class StartCommand < Kontena::Command
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME", "Service name"

    def execute
      require_api_url
      token = require_token
      spinner "Sending start signal to #{name.colorize(:cyan)} service " do
        start_service(token, name)
      end
    end
  end
end

require_relative 'services_helper'

module Kontena::Cli::Services
  class StartCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include ServicesHelper

    parameter "NAME ...", "Service name", attribute_name: :names

    def execute
      require_api_url
      token = require_token
      names.each do |name|
        spinner "Sending start signal to #{pastel.cyan(name)} service " do
          start_service(token, name)
        end
      end
    end
  end
end

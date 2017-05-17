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
      begin
        show_service_instances(token, name)
      rescue Kontena::Errors::StandardError => exc
        if exc.status == 404
          # fallback to old behaviour
          show_service_containers(token, name)
        end
      end
    end
  end
end

require_relative '../services_helper'

module Kontena::Cli::Services::Envs
  class ListCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Services::ServicesHelper

    parameter "NAME", "Service name"

    def execute
      require_api_url
      token = require_token
      service = client(token).get("services/#{parse_service_id(name)}")
      service["env"].sort.each do |env|
        puts env
      end
    end
  end
end

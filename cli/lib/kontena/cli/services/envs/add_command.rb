require_relative '../services_helper'

module Kontena::Cli::Services::Envs
  class AddCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Services::ServicesHelper

    parameter "SERVICE_NAME", "Service name", attribute_name: :name
    parameter "ENV", "Environment variable"

    def execute
      require_api_url
      token = require_token
      data = {env: env}
      spinner "Adding env variable to #{name.colorize(:cyan)} service " do
        client(token).post("services/#{parse_service_id(name)}/envs", data)
      end
    end
  end
end

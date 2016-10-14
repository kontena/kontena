require_relative '../services_helper'

module Kontena::Cli::Services::Envs
  class AddCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Services::ServicesHelper

    parameter "NAME", "Service name"
    parameter "ENV", "Environment variable"

    requires_current_master_token

    def execute
      data = {env: env}
      spinner "Adding env variable to #{name.colorize(:cyan)} service " do
        client.post("services/#{parse_service_id(name)}/envs", data)
      end
    end
  end
end

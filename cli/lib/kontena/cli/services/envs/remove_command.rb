require_relative '../services_helper'

module Kontena::Cli::Services::Envs
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Services::ServicesHelper

    parameter "NAME", "Service name"
    parameter "ENV", "Environment variable name"

    def execute
      require_api_url
      token = require_token
      spinner "Removing env variable #{env.colorize(:cyan)} from #{name.colorize(:cyan)} service " do
        client(token).delete("services/#{parse_service_id(name)}/envs/#{env}")
      end
    end
  end
end

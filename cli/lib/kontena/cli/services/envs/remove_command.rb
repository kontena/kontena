require_relative '../services_helper'

module Kontena::Cli::Services::Envs
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Services::ServicesHelper

    parameter "NAME", "Service name"
    parameter "ENV", "Environment variable name"

    requires_current_master_token

    def execute
      spinner "Removing env variable #{env.colorize(:cyan)} from #{name.colorize(:cyan)} service" do
        client.delete("services/#{parse_service_id(name)}/envs/#{env}")
      end
    end
  end
end

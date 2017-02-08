require_relative 'services_helper'

module Kontena::Cli::Services
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include ServicesHelper

    parameter "NAME", "Service name"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    def execute
      require_api_url
      token = require_token
      confirm_command(name) unless forced?

      spinner "Removing service #{name.colorize(:cyan)} " do
        client(token).delete("services/#{parse_service_id(name)}")
        removed = false
        until removed == true
          sleep 1
          begin
            client(token).get("services/#{parse_service_id(name)}")
          rescue Kontena::Errors::StandardError => exc
            if exc.status == 404
              removed = true
            else
              raise exc
            end
          end
        end
      end
    end
  end
end

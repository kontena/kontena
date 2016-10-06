require_relative 'services_helper'

module Kontena::Cli::Services
  class RemoveCommand < Kontena::Command
    include Kontena::Cli::Common
    include ServicesHelper

    parameter "NAME", "Service name"
    option "--force", :flag, "Force remove", default: false, attribute_name: :forced

    requires_current_master_token

    def execute
      confirm_command(name) unless forced?

      spinner "Removing service #{name.colorize(:cyan)} " do
        client.delete("services/#{parse_service_id(name)}")
        removed = false
        until removed == true
          begin
            client.get("services/#{parse_service_id(name)}")
            sleep 0.1
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

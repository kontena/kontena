require_relative 'services_helper'

module Kontena::Cli::Services
  class RemoveCommand < Clamp::Command
    include Kontena::Cli::Common
    include ServicesHelper

    parameter "NAME", "Service name"
    option "--confirm", :flag, "Confirm remove", default: false, attribute_name: :confirmed

    def execute
      require_api_url
      token = require_token
      confirm_command(name) unless confirmed?

      result = client(token).delete("services/#{parse_service_id(name)}")
    end
  end
end

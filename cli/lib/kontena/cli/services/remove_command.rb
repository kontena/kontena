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

      result = client(token).delete("services/#{parse_service_id(name)}")
    end
  end
end

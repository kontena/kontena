require_relative '../services_helper'

module Kontena::Cli::Services::Secrets
  class UnlinkCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Services::ServicesHelper

    parameter "SERVICE_NAME", "Service name", attribute_name: :name
    parameter "SECRET", "Secret to be removed (format: secret:name:type)", completion: "SECRET_NAME" # at least you get to complete something

    def execute
      require_api_url
      token = require_token
      result = client(token).get("services/#{parse_service_id(name)}")
      secrets = result['secrets']
      remove_secret = parse_secrets([secret])[0]
      if secrets.delete_if{|s| s['name'] == remove_secret[:name] && s['secret'] == remove_secret[:secret]}
        data = {
          secrets: secrets
        }
        client(token).put("services/#{parse_service_id(name)}", data)
      else
        exit_with_error("Secret not found")
      end
    end
  end
end

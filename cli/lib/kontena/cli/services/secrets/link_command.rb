require_relative '../services_helper'

module Kontena::Cli::Services::Secrets
  class LinkCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Services::ServicesHelper

    parameter "SERVICE_NAME", "Service name", attribute_name: :name
    parameter "SECRET", "Secret to be added from Vault (format: secret:name:type)", completion: "SECRET_NAME" # at least you get to complete something

    def execute
      require_api_url
      token = require_token
      spinner "Linking #{secret.colorize(:cyan)} from Vault to #{name.colorize(:cyan)} " do
        result = client(token).get("services/#{parse_service_id(name)}")
        secrets = result['secrets']
        secrets << parse_secrets([secret])[0]
        data = {
          secrets: secrets
        }
        client(token).put("services/#{parse_service_id(name)}", data)
      end
    end
  end
end

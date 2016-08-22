require_relative '../services_helper'

module Kontena::Cli::Services::Secrets
  class LinkCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Services::ServicesHelper

    parameter "NAME", "Service name"
    parameter "SECRET", "Secret to be added from Vault (format: secret:name:type)"

    def execute
      require_api_url
      token = require_token
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

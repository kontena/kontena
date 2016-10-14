require_relative '../services_helper'

module Kontena::Cli::Services::Secrets
  class LinkCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Kontena::Cli::Services::ServicesHelper

    parameter "NAME", "Service name"
    parameter "SECRET", "Secret to be added from Vault (format: secret:name:type)"

    requires_current_master_token

    def execute
      spinner "Linking #{secret.colorize(:cyan)} from Vault to #{name.colorize(:cyan)} " do
        result = client.get("services/#{parse_service_id(name)}")
        secrets = result['secrets']
        secrets << parse_secrets([secret])[0]
        data = {
          secrets: secrets
        }
        client.put("services/#{parse_service_id(name)}", data)
      end
    end
  end
end

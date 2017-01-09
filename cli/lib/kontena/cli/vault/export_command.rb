module Kontena::Cli::Vault
  class ExportCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    def execute
      require_api_url
      require_current_grid

      token = require_token

      secrets = client(token).get("grids/#{current_grid}/secrets").fetch('secrets')

      secrets_map = secrets.sort_by { |s| s['name'] }.map do |secret|
        name = secret.fetch('name')
        value = client(token)
                .get("secrets/#{current_grid}/#{name}")
                .fetch('value')
        [name, value]
      end
      puts Hash[secrets_map].to_yaml
    end
  end
end

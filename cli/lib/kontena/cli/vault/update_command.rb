module Kontena::Cli::Vault
  class UpdateCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter 'NAME', 'Secret name'
    parameter '[VALUE]', 'Secret value'
    option ['-u', '--upsert'], :flag, 'Create secret unless already exists', default: false

    def execute
      require_api_url
      require_current_grid

      token = require_token
      secret = value
      if secret.to_s == ''
        secret = STDIN.read
      end
      abort('No value provided') if secret.to_s == ''
      data = {
        name: name,
        value: secret,
        upsert: upsert?
      }
      client(token).put("grids/#{current_grid}/secrets/#{name}", data)
    end
  end
end

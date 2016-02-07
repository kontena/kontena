module Kontena::Cli::Vault
  class WriteCommand < Clamp::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter 'NAME', 'Secret name'
    parameter '[VALUE]', 'Secret value'

    def execute
      require_api_url
      token = require_token
      secret = value
      if secret.to_s == ''
        secret = STDIN.read
      end
      abort('No value provided') if secret.to_s == ''
      data = {
          name: name,
          value: secret
      }
      client(token).post("grids/#{current_grid}/secrets", data)
    end
  end
end

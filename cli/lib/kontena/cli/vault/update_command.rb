module Kontena::Cli::Vault
  class UpdateCommand < Clamp::Command
    include Kontena::Cli::Common

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
      data = {value: secret}
      client(token).put("grids/#{current_grid}/secrets/#{name}", data)
    end
  end
end

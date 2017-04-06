module Kontena::Cli::Vault
  class WriteCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter 'NAME', 'Secret name'
    parameter '[VALUE]', 'Secret value'

    option '--silent', :flag, "Reduce output verbosity"

    def execute
      require_api_url
      require_current_grid

      token = require_token
      secret = value
      if secret.to_s == ''
        secret = STDIN.read.chomp
      end
      exit_with_error('No value provided') if secret.to_s == ''
      data = {
          name: name,
          value: secret
      }
      vspinner "Writing #{name.colorize(:cyan)} to the vault " do
        client(token).post("grids/#{current_grid}/secrets", data)
      end
    end
  end
end

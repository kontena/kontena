module Kontena::Cli::Vault
  class WriteCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter 'NAME', 'Secret name'
    parameter '[VALUE]', 'Secret value'

    requires_current_master_token

    def execute
      secret = value
      if secret.to_s == ''
        secret = STDIN.read
      end
      exit_with_error('No value provided') if secret.to_s == ''
      data = {
          name: name,
          value: secret
      }
      spinner "Writing #{name.colorize(:cyan)} to the vault " do
        client.post("grids/#{current_grid}/secrets", data)
      end
    end
  end
end

module Kontena::Cli::Vault
  class UpdateCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter 'NAME', 'Secret name'
    parameter '[VALUE]', 'Secret value'
    option ['-u', '--upsert'], :flag, 'Create secret unless already exists', default: false

    requires_current_master_token

    def execute
      secret = value
      if secret.to_s == ''
        secret = STDIN.read
      end
      exit_with_error('No value provided') if secret.to_s == ''
      data = {
        name: name,
        value: secret,
        upsert: upsert?
      }
      spinner "Updating #{name.colorize(:cyan)} value in the vault " do
        client.put("grids/#{current_grid}/secrets/#{name}", data)
      end
    end
  end
end

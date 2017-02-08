module Kontena::Cli::Vault
  class UpdateCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter 'NAME', 'Secret name'
    parameter '[VALUE]', 'Secret value'

    option ['-u', '--upsert'], :flag, 'Create secret unless already exists', default: false
    option '--silent', :flag, "Reduce output verbosity"

    def execute
      require_api_url
      require_current_grid

      token = require_token
      value ||= STDIN.read.chomp
      data = {
        name: name,
        value: value,
        upsert: upsert?
      }
      vspinner "Updating #{name.colorize(:cyan)} value in the vault " do
        client(token).put("secrets/#{current_grid}/#{name}", data)
      end
    end
  end
end

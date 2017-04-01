module Kontena::Cli::Vault
  class UpdateCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter 'NAME', 'Secret name'
    parameter '[VALUE]', 'Secret value'

    option ['-u', '--upsert'], :flag, 'Create secret unless already exists', default: false
    option '--silent', :flag, "Reduce output verbosity"
    option ['-i', '--stdin'], :flag, 'Read value from stdin', default: false

    def default_value
      exit_with_error('No value provided') unless stdin?
      STDIN.read.chomp
    end

    def execute
      require_api_url
      require_current_grid

      token = require_token
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

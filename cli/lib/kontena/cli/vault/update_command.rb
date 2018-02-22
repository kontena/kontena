module Kontena::Cli::Vault
  class UpdateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter 'NAME', 'Secret name'
    parameter '[VALUE]', 'Secret value (default: STDIN)'

    option ['-u', '--upsert'], :flag, 'Create secret unless already exists', default: false
    option '--silent', :flag, "Reduce output verbosity"

    requires_current_master

    def default_value
      stdin_input("Enter value for secret '#{name}'", :mask)
    end

    def execute
      vspinner "Updating #{pastel.cyan(name)} value in the vault " do
        client.put("secrets/#{current_grid}/#{name}", {name: name, value: value, upsert: upsert? })
      end
    end
  end
end

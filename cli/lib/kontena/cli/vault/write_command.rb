module Kontena::Cli::Vault
  class WriteCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter 'NAME', 'Secret name'
    parameter '[VALUE]', 'Secret value (default: STDIN)'

    option '--silent', :flag, "Reduce output verbosity"

    requires_current_master

    def default_value
      stdin_input("Enter value for secret '#{name}'", :mask)
    end

    def execute
      vspinner "Writing #{pastel.cyan(name)} to the vault " do
        client.post("grids/#{current_grid}/secrets", { name: name, value: value })
      end
    end
  end
end

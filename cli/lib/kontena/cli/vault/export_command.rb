module Kontena::Cli::Vault
  class ExportCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    banner "Exports secrets from Vault to STDOUT as YAML or JSON."

    requires_current_master

    option '--json', :flag, "Output JSON"

    def execute
      require 'shellwords'
      meth = json? ? :to_json : :to_yaml
      puts Hash[
        *Kontena.run!(['vault', 'ls', '--return']).sort.flat_map do |secret|
          [secret, Kontena.run!(['vault', 'read', '--return', secret])]
        end
      ].send(meth)
    end
  end
end

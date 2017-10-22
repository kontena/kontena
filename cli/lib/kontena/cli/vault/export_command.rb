module Kontena::Cli::Vault
  class ExportCommand < Kontena::Command
    include Kontena::Cli::GridOptions

    banner "Exports secrets from Vault to STDOUT as YAML or JSON."

    requires_current_master

    option '--json', :flag, "Output JSON"

    def execute
      require 'shellwords'
      require 'json'
      require 'yaml'
      meth = json? ? :to_json : :to_yaml
      puts(
        Kontena.run!(['vault', 'ls', '--return']).sort.map do |secret|
          [secret, Kontena.run!(['vault', 'read', '--return', secret])]
        end.to_h.send(meth)
      )
    end
  end
end

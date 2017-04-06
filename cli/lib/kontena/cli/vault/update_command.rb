module Kontena::Cli::Vault
  class UpdateCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter 'NAME', 'Secret name'
    parameter '[VALUE]', 'Secret value'

    option ['-u', '--upsert'], :flag, 'Create secret unless already exists', default: false
    option '--silent', :flag, "Reduce output verbosity"

    requires_current_master
    requires_current_master_token

    def execute
      unless value
        if !$stdin.tty? && $stdin.closed?
          exit_with_error('No value provided')
        end
        STDERR.puts("Enter a value for #{Kontena.pastel.cyan(name)}, press #{Kontena.pastel.yellow("ctrl-d")} when finished:") if $stdin.tty?
        value = $stdin.read
      end
      vspinner "Updating #{Kontena.pastel.cyan(name)} value to the vault " do
        client.put("secrets/#{current_grid}/#{name}", { name: name, value: value, upsert: upsert? })
      end
    end
  end
end

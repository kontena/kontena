module Kontena::Cli::Vault
  class WriteCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    parameter 'NAME', 'Secret name'
    parameter '[VALUE]', 'Secret value'

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
      vspinner "Writing #{name.colorize(:cyan)} to the vault " do
        client.post("grids/#{current_grid}/secrets", { name: name, value: value })
      end
    end
  end
end

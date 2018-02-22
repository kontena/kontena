module Kontena::Cli::Grids
  class TrustedSubnetCommand < Kontena::Command
    subcommand ["list", "ls"], "List trusted subnets", load_subcommand('grids/trusted_subnets/list_command')
    subcommand "add", "Add trusted subnet", load_subcommand('grids/trusted_subnets/add_command')
    subcommand ["remove", "rm"], "Remove trusted subnet", load_subcommand('grids/trusted_subnets/remove_command')

    def execute
    end
  end
end

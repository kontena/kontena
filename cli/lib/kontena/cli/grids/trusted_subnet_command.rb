module Kontena::Cli::Grids


  class TrustedSubnetCommand < Kontena::Command
    subcommand ["list", "ls"], "List trusted subnets", Trustedload_subcommand('subnets/list_command')
    subcommand "add", "Add trusted subnet", Trustedload_subcommand('subnets/add_command')
    subcommand ["remove", "rm"], "Remove trusted subnet", Trustedload_subcommand('subnets/remove_command')
  end
end
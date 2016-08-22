module Kontena::Cli::Grids

  require_relative 'trusted_subnets/list_command'
  require_relative 'trusted_subnets/add_command'
  require_relative 'trusted_subnets/remove_command'

  class TrustedSubnetCommand < Kontena::Command
    subcommand ["list", "ls"], "List trusted subnets", TrustedSubnets::ListCommand
    subcommand "add", "Add trusted subnet", TrustedSubnets::AddCommand
    subcommand ["remove", "rm"], "Remove trusted subnet", TrustedSubnets::RemoveCommand
  end
end

module Kontena::Cli::Services

  require_relative 'envs/add_command'
  require_relative 'envs/list_command'
  require_relative 'envs/remove_command'

  class EnvCommand < Kontena::Command
    subcommand ["list", "ls"], "List service environment variables", Envs::ListCommand
    subcommand "add", "Add environment variable", Envs::AddCommand
    subcommand ["remove", "rm"], "Remove environment variable", Envs::RemoveCommand
  end
end

module Kontena::Cli::Services


  class EnvCommand < Kontena::Command
    subcommand ["list", "ls"], "List service environment variables", load_subcommand('envs/list_command')
    subcommand "add", "Add environment variable", load_subcommand('envs/add_command')
    subcommand ["remove", "rm"], "Remove environment variable", load_subcommand('envs/remove_command')
  end
end
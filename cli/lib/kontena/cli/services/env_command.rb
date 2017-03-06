module Kontena::Cli::Services


  class EnvCommand < Kontena::Command
    subcommand ["list", "ls"], "List service environment variables", load_subcommand('services/envs/list_command')
    subcommand "add", "Add environment variable", load_subcommand('services/envs/add_command')
    subcommand ["remove", "rm"], "Remove environment variable", load_subcommand('services/envs/remove_command')
  end
end

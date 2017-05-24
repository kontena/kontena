module Kontena::Cli::Stacks
  class RegistryCommand < Kontena::Command
    subcommand "push", "Push a stack into the stacks registry", load_subcommand('stacks/registry/push_command')
    subcommand "pull", "Pull a stack from the stacks registry", load_subcommand('stacks/registry/pull_command')
    subcommand "search", "Search for stacks in the stacks registry", load_subcommand('stacks/registry/search_command')
    subcommand "show", "Show info about a stack in the stacks registry", load_subcommand('stacks/registry/show_command')
    subcommand ["remove", "rm"], "Remove a stack (or version) from the stacks registry", load_subcommand('stacks/registry/remove_command')
  end
end

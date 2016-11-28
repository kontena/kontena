module Kontena::Cli::Stacks

  require_relative 'registry/push_command'
  require_relative 'registry/pull_command'
  require_relative 'registry/search_command'
  require_relative 'registry/show_command'

  class RegistryCommand < Kontena::Command

    subcommand "push", "Push (or delete) a stack into the stacks registry", Registry::PushCommand
    subcommand "pull", "Pull a stack from the stacks registry", Registry::PullCommand
    subcommand "search", "Search for stacks in the stacks registry", Registry::SearchCommand
    subcommand "show", "Show info about a stack in the stacks registry", Registry::ShowCommand
  end
end

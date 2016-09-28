require_relative 'token/list_command'
require_relative 'token/remove_command'
require_relative 'token/create_command'
require_relative 'token/current_command'
require_relative 'token/show_command'

module Kontena::Cli::Master
  class TokenCommand < Kontena::Command
    subcommand ["list", "ls"], "List access tokens", Kontena::Cli::Master::Token::ListCommand
    subcommand ["rm", "remove"], "Remove / revoke an access token", Kontena::Cli::Master::Token::RemoveCommand
    subcommand "show", "Display access token", Kontena::Cli::Master::Token::ShowCommand
    subcommand "current", "Display current access token", Kontena::Cli::Master::Token::CurrentCommand
    subcommand "create", "Generate an access token", Kontena::Cli::Master::Token::CreateCommand

    def execute
    end
  end
end

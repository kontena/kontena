
module Kontena::Cli::Master
  class TokenCommand < Kontena::Command
    subcommand ["list", "ls"], "List access tokens", load_subcommand('master/token/list_command')
    subcommand ["rm", "remove"], "Remove / revoke an access token", load_subcommand('master/token/remove_command')
    subcommand "show", "Display access token", load_subcommand('master/token/show_command')
    subcommand "current", "Display current access token", load_subcommand('master/token/current_command')
    subcommand "create", "Generate an access token", load_subcommand('master/token/create_command')

    def execute
    end
  end
end
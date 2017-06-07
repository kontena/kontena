module Kontena::Cli
  class LoginCommand < Kontena::Command
    subcommand "master", "Login to a Kontena Master", load_subcommand('master/login_command')
    subcommand "cloud", "Login to a Kontena Cloud account", load_subcommand('cloud/login_command')
  end
end

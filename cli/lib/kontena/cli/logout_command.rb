class Kontena::Cli::LogoutCommand < Kontena::Command
  subcommand "master", "Logout from Kontena Masters", load_subcommand('master/logout_command')
  subcommand "cloud", "Logout from Kontena Cloud account", load_subcommand('cloud/logout_command')
end

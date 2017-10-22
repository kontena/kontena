class Kontena::Cli::CloudCommand < Kontena::Command
  subcommand "login", "Authenticate to Kontena Cloud", load_subcommand('cloud/login_command')
  subcommand "logout", "Logout from Kontena Cloud", load_subcommand('cloud/logout_command')
  subcommand "master", "Master specific commands", load_subcommand('cloud/master_command')
end

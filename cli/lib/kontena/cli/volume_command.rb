
class Kontena::Cli::VolumeCommand < Kontena::Command

  warn Kontena.pastel.yellow("[EXPERIMENTAL] The `kontena volume` commands are still experimental in Kontena #{Kontena.minor_version}, and may change in future releases")

  subcommand "create", "Create a managed volume", load_subcommand('volumes/create_command')
  subcommand "show", "Show details of a volume", load_subcommand('volumes/show_command')
  subcommand ["remove", "rm"], "Remove a managed volume", load_subcommand('volumes/remove_command')
  subcommand ["list", "ls"], "List managed volumes", load_subcommand('volumes/list_command')

end

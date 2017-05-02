class Kontena::Cli::LogoutCommand < Kontena::Command

  banner "Command removed, use 'kontena master logout' to log out of the Kontena Master"
  banner "or 'kontena cloud logout' to log out of the Kontena Cloud", false

  def execute
    exit_with_error("Command removed. Use #{"kontena master logout".colorize(:yellow)} to log out of the Kontena Master")
  end
end

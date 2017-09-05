class Kontena::Cli::LogoutCommand < Kontena::Command
  include Kontena::Cli::Common

  banner "Command removed, use 'kontena master logout' to log out of the Kontena Master"
  banner "or 'kontena cloud logout' to log out of the Kontena Cloud", false

  def execute
    exit_with_error("Command removed. Use #{pastel.yellow("kontena master logout")} to log out of the Kontena Master")
  end
end

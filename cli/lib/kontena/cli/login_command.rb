class Kontena::Cli::LoginCommand < Kontena::Command
  include Kontena::Cli::Common

  parameter "URL", "url"

  banner "Command removed, use 'kontena cloud login' to authenticate to a Kontena Cloud account"
  banner "or 'kontena master login' to authenticate to a Kontena Master", false

  def execute
    abort("Command removed. Use #{"kontena master login #{self.url}".colorize(:yellow)} to login to a Kontena Master")
  end
end

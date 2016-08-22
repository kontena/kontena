class Kontena::Cli::LogoutCommand < Kontena::Command
  include Kontena::Cli::Common

  def execute
    self.access_token = nil
  end
end

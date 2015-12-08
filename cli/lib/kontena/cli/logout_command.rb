class Kontena::Cli::LogoutCommand < Clamp::Command
  include Kontena::Cli::Common

  def execute
    self.access_token = nil
  end
end

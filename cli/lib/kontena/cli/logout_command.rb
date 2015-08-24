class Kontena::Cli::LogoutCommand < Clamp::Command
  include Kontena::Cli::Common

  def execute
    settings['server'].delete('token')
    save_settings
  end
end

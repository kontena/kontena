require_relative 'user/verify_command'
require_relative 'user/forgot_password_command'
require_relative 'user/reset_password_command'

class Kontena::Cli::UserCommand < Kontena::Command

  subcommand "verify", "Verify user account", Kontena::Cli::User::VerifyCommand
  subcommand "forgot-password", "Request password reset for Kontena account", Kontena::Cli::User::ForgotPasswordCommand
  subcommand "reset-password", "Reset Kontena account password", Kontena::Cli::User::ResetPasswordCommand

  def execute
  end
end

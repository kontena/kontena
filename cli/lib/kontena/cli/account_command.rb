require_relative 'account/use_command'
require_relative 'account/list_command'
require_relative 'account/auth_command'
require_relative 'account/register_command'
require_relative 'account/verify_command'
require_relative 'account/forgot_password_command'
require_relative 'account/reset_password_command'

class Kontena::Cli::AccountCommand < Clamp::Command

  subcommand ["list", "ls"], "List accounts", Kontena::Cli::Account::ListCommand
  subcommand "use", "Use account <account name>", Kontena::Cli::Account::UseCommand
  subcommand "auth", "Authenticate to account <account name>", Kontena::Cli::Account::AuthCommand

  subcommand "register", "Register account", Kontena::Cli::Account::RegisterCommand
  subcommand "verify", "Verify account", Kontena::Cli::Account::VerifyCommand
  subcommand "forgot-password", "Request password reset for Kontena account", Kontena::Cli::Account::ForgotPasswordCommand
  subcommand "reset-password", "Reset Kontena account password", Kontena::Cli::Account::ResetPasswordCommand

  def execute
  end
end

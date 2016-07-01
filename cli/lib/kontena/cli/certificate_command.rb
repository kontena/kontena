require_relative 'certificate/register_command'
require_relative 'certificate/authorize_command'
require_relative 'certificate/get_command'

class Kontena::Cli::CertificateCommand < Clamp::Command


  subcommand "register", "Register to LetsEncrypt", Kontena::Cli::Certificate::RegisterCommand
  subcommand "authorize", "Create DNS authorization for domain", Kontena::Cli::Certificate::AuthorizeCommand
  subcommand "get", "Get certificate for domain", Kontena::Cli::Certificate::GetCommand

  def execute
  end
end

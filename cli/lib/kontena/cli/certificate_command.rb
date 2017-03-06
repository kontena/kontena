
class Kontena::Cli::CertificateCommand < Kontena::Command


  subcommand "register", "Register to LetsEncrypt", load_subcommand('certificate/register_command')
  subcommand "authorize", "Create DNS authorization for domain", load_subcommand('certificate/authorize_command')
  subcommand "get", "Get certificate for domain", load_subcommand('certificate/get_command')

  def execute
  end
end

class Kontena::Cli::CertificateCommand < Kontena::Command

  subcommand ["list", "ls"], "List certificates", load_subcommand('certificate/list_command')
  subcommand "show", "Show certificate details", load_subcommand('certificate/show_command')
  subcommand "register", "Register to LetsEncrypt", load_subcommand('certificate/register_command')
  subcommand "authorize", "Create DNS authorization for domain", load_subcommand('certificate/authorize_command')
  subcommand "request", "Request certificate for domain", load_subcommand('certificate/request_command')
  subcommand "get", "Get certificate for domain", load_subcommand('certificate/get_command')
  subcommand ["remove", "rm"], "Remove certificate for domain", load_subcommand('certificate/remove_command')


  def execute
  end
end
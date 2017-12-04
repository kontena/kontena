
class Kontena::Cli::CloudCommand < Kontena::Command
  include Kontena::Cli::Common

  subcommand "login", "Authenticate to Kontena Cloud", load_subcommand('cloud/login_command')
  subcommand "logout", "Logout from Kontena Cloud", load_subcommand('cloud/logout_command')
  subcommand "master", "Master specific commands", load_subcommand('cloud/master_command')

  def subcommand_missing(name)
    return super(name) unless %w(platform node org organization image-repository ir region token).include?(name)
    exit_with_error "The #{pastel.cyan('cloud')} plugin has not been installed. Use: #{pastel.cyan('kontena plugin install cloud')}"
  end
end

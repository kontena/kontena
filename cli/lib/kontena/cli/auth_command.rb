require 'launchy'
require_relative "./localhost_web_server"
require_relative "auth/master_command"
#require_relative "auth/account_command"
require 'uri'

class Kontena::Cli::AuthCommand < Clamp::Command
  include Kontena::Cli::Common
  
  subcommand "master", "Authenticate to a Kontena Master", Kontena::Cli::Auth::MasterCommand
  #subcommand "account", "Authenticate to Kontena Cloud account", Kontena::Cli::Auth::AccountCommand

  def execute
  end
end


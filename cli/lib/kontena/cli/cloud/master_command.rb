require_relative 'master/add_command'
require_relative 'master/list_command'
require_relative 'master/remove_command'
require_relative 'master/update_command'
require_relative 'master/show_command'
require_relative 'master/login_command'

module Kontena::Cli::Cloud
  class MasterCommand < Kontena::Command
    include Kontena::Cli::Common

    subcommand ['list', 'ls'], "List masters in Kontena Cloud", Kontena::Cli::Cloud::Master::ListCommand
    subcommand 'login', "Login to a Kontena Master registered to Kontena Cloud", Kontena::Cli::Cloud::Master::LoginCommand
    subcommand ['remove', 'rm'], "Remove a master registration from Kontena Cloud", Kontena::Cli::Cloud::Master::RemoveCommand
    subcommand "add", "Register a master in Kontena Cloud", Kontena::Cli::Cloud::Master::AddCommand
    subcommand "show", "Show master settings in Kontena Cloud", Kontena::Cli::Cloud::Master::ShowCommand
    subcommand "update", "Update master settings in Kontena Cloud", Kontena::Cli::Cloud::Master::UpdateCommand

    def execute
    end
  end
end


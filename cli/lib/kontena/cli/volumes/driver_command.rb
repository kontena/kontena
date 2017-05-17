module Kontena::Cli::Volumes
  class DriverCommand < Kontena::Command
    subcommand "install", "Install plugin", load_subcommand('volumes/drivers/install_command')
    
    def execute
    end
  end
end
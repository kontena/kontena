require_relative 'config/set_command'
require_relative 'config/get_command'
require_relative 'config/unset_command'
require_relative 'config/export_command'
require_relative 'config/import_command'

module Kontena
  module Cli
    module Master
      class ConfigCommand < Kontena::Command

        subcommand "set", "Set a config value", Kontena::Cli::Master::Config::SetCommand
        subcommand "get", "Get a config value", Kontena::Cli::Master::Config::GetCommand
        subcommand "unset", "Clear a config value", Kontena::Cli::Master::Config::UnsetCommand
        subcommand ["load", "import"], "Upload config to Master", Kontena::Cli::Master::Config::ImportCommand
        subcommand ["dump", "export"], "Download config from Master", Kontena::Cli::Master::Config::ExportCommand

        def execute
        end
      end
    end
  end
end


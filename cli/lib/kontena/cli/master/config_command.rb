module Kontena
  module Cli
    module Master
      class ConfigCommand < Kontena::Command
        subcommand "set", "Set a config value", load_subcommand('master/config/set_command')
        subcommand "get", "Get a config value", load_subcommand('master/config/get_command')
        subcommand "unset", "Clear a config value", load_subcommand('master/config/unset_command')
        subcommand ["load", "import"], "Upload config to Master", load_subcommand('master/config/import_command')
        subcommand ["dump", "export"], "Download config from Master", load_subcommand('master/config/export_command')

        def execute
        end
      end
    end
  end
end

module Kontena
  module Callbacks
    class ClearCurrentMasterAfterTerminate < Kontena::Callback

      include Kontena::Cli::Common

      matches_commands 'master terminate'

      def after
        return unless command.exit_code == 0
        return unless config.current_master

        ENV["DEBUG"] && $stderr.puts("Removing current master from config")
        config.servers.delete_at(config.find_server_index(config.current_master.name))
        config.current_server = nil
        config.write
      end
    end
  end
end

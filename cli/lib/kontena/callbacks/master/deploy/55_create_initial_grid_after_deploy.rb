module Kontena
  module Callbacks
    class CreateInitialGridAfterDeploy < Kontena::Callback

      include Kontena::Cli::Common

      matches_commands 'master create'

      def after
        return unless command.exit_code == 0
        return unless config.current_master
        return unless config.current_master.name == command.result[:name]

        cmd = "grid create --silent test"
        ENV["DEBUG"] && $stderr.puts("Running: #{cmd}")
        Retriable.retriable do
          Kontena.run(cmd)
        end
      end
    end
  end
end

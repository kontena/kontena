module Kontena
  module Callbacks
    class CreateInitialGridAfterDeploy < Kontena::Callback

      matches_commands 'master create'

      def after
        extend Kontena::Cli::Common

        return unless command.exit_code == 0
        return unless config.current_master
        return unless config.current_master.name == command.result[:name]

        cmd = %w(grid create --silent test)
        Retriable.retriable do
          Kontena.run!(cmd)
        end
      end
    end
  end
end

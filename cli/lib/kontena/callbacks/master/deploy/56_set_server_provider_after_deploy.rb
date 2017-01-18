module Kontena
  module Callbacks
    class SetServerProviderAfterDeploy < Kontena::Callback

      include Kontena::Cli::Common

      matches_commands 'master create'

      def after
        return unless command.exit_code == 0
        return unless config.current_master
        return unless config.current_master.name == command.result[:name]
        return unless command.result[:provider]

        cmd = ['master', 'config', 'set', "server.provider=#{command.result[:provider]}".shellescape]
        spinner "Setting Master configuration server.provider to '#{command.result[:provider]}'" do
          Retriable.retriable do
            Kontena.run(*cmd)
          end
        end
      end
    end
  end
end


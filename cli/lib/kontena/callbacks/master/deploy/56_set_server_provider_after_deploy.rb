module Kontena
  module Callbacks
    class SetServerProviderAfterDeploy < Kontena::Callback

      matches_commands 'master create'

      def after
        extend Kontena::Cli::Common
        return unless command.exit_code == 0
        return unless config.current_master
        return unless config.current_master.name == command.result[:name]
        return unless command.result[:provider]

        require 'shellwords'

        cmd = ['master', 'config', 'set', "server.provider=#{command.result[:provider]}"]
        spinner "Setting Master configuration server.provider to '#{command.result[:provider]}'" do |spin|
          spin.fail! unless Kontena.run(cmd)
        end
      end
    end
  end
end


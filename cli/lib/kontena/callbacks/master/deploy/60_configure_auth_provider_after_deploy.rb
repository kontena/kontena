module Kontena
  module Callbacks
    class ConfigureAuthProviderAfterDeploy < Kontena::Callback

      include Kontena::Cli::Common

      matches_commands 'master create'

      def configure_auth_provider_using_id(cloud_id)
        Kontena.run("master init-cloud --force --cloud-master-id #{cloud_id.shellescape}")
      end

      def configure_auth_provider
        Kontena.run("master init-cloud --force")
      end

      def after
        return unless command.exit_code == 0
        return unless command.result.kind_of?(Hash)
        return unless command.result.has_key?(:name)
        return unless config.current_master
        return unless config.current_master.name == command.result[:name]
        if command.respond_to?(:skip_auth_provider?) && command.skip_auth_provider?
          return
        end

        if command.respond_to?(:cloud_master_id) && command.cloud_master_id
          configure_auth_provider_using_id(command.cloud_master_id)
        else
          configure_auth_provider
        end
      end
    end
  end
end


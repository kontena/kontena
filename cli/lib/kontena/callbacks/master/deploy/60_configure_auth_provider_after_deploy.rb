module Kontena
  module Callbacks
    class ConfigureAuthProviderAfterDeploy < Kontena::Callback

      include Kontena::Cli::Common

      matches_commands 'master create'

      def get_oauth_app_config(master_id)
        attrs = nil
        spinner "Retrieving master OAuth2 application settings from Kontena Cloud" do
          attrs = cloud_client.get("user/masters/#{master_id}")["data"]["attributes"]
        end
        attrs
      rescue
        nil
      end

      def configure_auth_provider(oauth_config)
        require 'shellwords'
        spinner "Setting Kontena Cloud authentication provider base settings to Master config" do
          Kontena.run("master config import --force --preset kontena_auth_provider")
        end
        spinner "Setting Kontena Cloud authentication provider consumer credentials to Master config" do
          Kontena.run("master config set oauth2.client_id=#{oauth_config['client-id'].shellescape} oauth2.client_secret=#{oauth_config['client-secret'].shellescape} server.root_url=#{config.current_master.url.shellescape}")
        end
      end

      def after
        return unless command.exit_code == 0
        return unless command.result.kind_of?(Hash)
        return unless command.result.has_key?(:name)
        return unless config.current_master
        return unless config.current_master.name == command.result[:name]
        if command.respond_to?(:skip_auth_provider) && command.skip_auth_provider?
          return
        end

        if command.respond_to?(:cloud_master_id) && command.cloud_master_id
          oauth_config = get_oauth_app_config(command.cloud_master_id)
          if oauth_config
            configure_auth_provider(oauth_config)
          end
        end
      end
    end
  end
end


require 'colorize'
require 'uri'

module Kontena
  module Cli
    module Common

      def require_api_url
        KontenaClient.config.require_master_url
      end

      def require_token
        KontenaClient.config.require_token
      end

      def client(_ = nil)
        KontenaClient.master.tap {|m| m.uri_path_prefix = 'v1'}
      end

      def reset_client
        KontenaClient.clear_master
      end

      def settings_filename
        KontenaClient.config.config_path
      end

      def settings
        KontenaClient.config.settings
      end

      def api_url
        require_api_url
      end

      def ensure_custom_ssl_ca(_)
        client.ensure_custom_ssl_ca
      end

      def current_grid=(grid)
        KontenaClient.config.update do |config|
          config.grid = grid
        end
      end

      def require_current_grid
        KontenaClient.config.require_grid
      end

      def clear_current_grid
        KontenaClient.config.update do |config|
          config.grid = nil
        end
      end

      def current_grid
        KontenaClient.config.grid
      rescue ArgumentError => e
        nil
      end

      def current_master
        require_api_url
        KontenaClient.config.current_master
      end

      def current_master=(master_alias)
        KontenaClient.config.update do |config|
          config.current_master = master_alias
        end
      end

      def error(message = nil)
        $stderr.puts(message) if message
        exit(1)
      end

      def prompt(prefix = '> ')
        require 'highline/import'
        ask(prefix)
      end

      def confirm_command(name, message = nil)
        puts message if message
        puts "Destructive command. To proceed, type \"#{name}\" or re-run this command with --force option."

        prompt == name || error("Confirmation did not match #{name}. Aborted command.")
      end

      def confirm(message = 'Destructive command. Are you sure? (y/n) or re-run this command with --force option.')
        puts message

        ['y', 'yes'].include?(prompt) || error("Aborted command.")
      end

      def api_url=(api_url)
        require_api_url
        KontenaClient.config.update do |config|
          config.current_master['url'] = api_url
        end
      end

      def access_token=(token)
        KontenaClient.config.update do |config|
          config.token = token
        end
      end

      def add_master(server_name, master_info)
        KontenaClient.config.add_master(server_name, master_info)
      end

      def save_settings
        KontenaClient.config.update
      end
    end
  end
end

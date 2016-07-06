require 'kontena_client'
require 'colorize'
require 'uri'

module Kontena
  module Cli
    module Common
      KONTENA_CLIENT_ID = 'f6c8f109754c472f955a2eec24e80f9f'.freeze
      KONTENA_CLIENT_SECRET = '311908953ffe489da4c1403c178bdd6e'.freeze

      def require_api_url
        KontenaClient.config.require_master_url
      end

      def require_token
        KontenaClient.config.require_token
      end

      def client(token = nil)
        return @client if @client
        @client = KontenaClient.master
        @client.uri_path_prefix = 'v1'
        KontenaClient.config.client_id = KONTENA_CLIENT_ID
        KontenaClient.config.client_secret = KONTENA_CLIENT_SECRET
        @client
      end

      def reset_client
        @client = nil
      end

      def settings_filename
        KontenaClient.config.config_path
      end

      def settings
        KontenaClient.config.settings
      end

      def api_url
        KontenaClient.config.url
      end

      def current_grid=(grid)
        KontenaClient.config.grid = grid
      end

      def require_current_grid
        KontenaClient.config.require_grid
      end

      def clear_current_grid
        KontenaClient.config.grid = nil
      end

      def current_grid
        KontenaClient.config.grid
      rescue ArgumentError => e
        nil      
      end

      def current_master
        KontenaClient.config.current_master
      end

      def current_master=(master_alias)
        KontenaClient.master = master_alias
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
        KontenaClient.config.url = api_url
      end

      def access_token=(token)
        KontenaClient.config.token = token
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

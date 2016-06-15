require 'colorize'
require 'uri'

module Kontena
  module Cli
    module Common
      def require_api_url
        api_url
      end

      def require_token
        token = ENV['KONTENA_TOKEN'] || current_master['token'] || current_account['token']
        unless token
          raise ArgumentError.new("Please login first using: kontena login")
        end
        token
      end

      def client(token = nil)
        @client ||= Kontena.master_client
      end

      def reset_client
        @client = nil
      end

      def settings_filename
        Kontena.config.settings_filename
      end

      def settings
        Kontena.config.settings
      end

      def api_url
        url = ENV['KONTENA_URL'] || current_master['url']
        unless url
          raise ArgumentError.new("It seem's that you are not logged into Kontena master, please login with: kontena login")
        end
        ensure_custom_ssl_ca(url)
        url
      end

      def ensure_custom_ssl_ca(url)
        return if Excon.defaults[:ssl_ca_file]

        uri = URI::parse(url)
        cert_file = File.join(Dir.home, "/.kontena/certs/#{uri.host}.pem")
        if File.exist?(cert_file)
          Excon.defaults[:ssl_ca_file] = cert_file
        end
      end

      def current_grid=(grid)
        Kontena.config.current_grid=(grid)
      end

      def require_current_grid
        if current_grid.nil?
          raise ArgumentError.new("Please select grid first using: kontena grid use <grid name>")
        end
      end

      def clear_current_grid
        settings['servers'][current_master_index].delete('grid')
        save_settings
      end

      def current_grid
        if self.respond_to?(:grid)
          ENV['KONTENA_GRID'] || grid || current_master['grid']
        else
          ENV['KONTENA_GRID'] || current_master['grid']
        end
      rescue ArgumentError => e
        nil      
      end

      def current_master_index
        current_server = settings['current_server'] || 'default'
        settings['servers'].find_index{|m| m['name'] == current_server}
      end

      def current_account
        Kontena.config.current_account || {}
      end

      def current_master
        index = current_master_index
        unless index
          raise ArgumentError.new("It seem's that you are not logged into ANY Kontena master, please login with: kontena login")
        end
        settings['servers'][index]
      end

      def current_master=(master_alias)
        settings['current_server'] = master_alias
        save_settings
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
        settings['servers'][current_master_index]['url'] = api_url
        save_settings
      end

      def access_token=(token)
        settings['servers'][current_master_index]['token'] = token
        save_settings
      end

      def add_master(server_name, master_info)
        server_name = server_name || 'default'
        index = settings['servers'].find_index{|m| m['name'] == server_name}
        if index
          settings['servers'][index] = master_info
        else
          settings['servers'] << master_info
        end
        settings['current_server'] = server_name
        save_settings
      end

      def save_settings
        Kontena.config.update
      end
    end
  end
end

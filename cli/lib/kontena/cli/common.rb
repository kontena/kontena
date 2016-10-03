require 'colorize'
require 'uri'
require 'io/console'

require_relative 'config'

module Kontena
  module Cli
    module Common

      def logger
        return @logger if @logger
        @logger = Logger.new(STDOUT)
        @logger.level = ENV["DEBUG"].nil? ? Logger::INFO : Logger::DEBUG
        @logger.progname = 'COMMON'
        @logger
      end

      def config
        Kontena::Cli::Config.instance
      end

      def require_api_url
        config.require_current_master.url
      end

      def require_token
        retried ||= false
        config.require_current_master_token
      rescue Kontena::Cli::Config::TokenExpiredError
        if retried
          raise ArgumentError, "Current master access token has expired and refresh failed."
        else
          logger.debug "Access token expired, trying to refresh"
          retried = true
          client.refresh_token && retry
        end
      end

      def require_current_master
        config.require_current_master
      end

      def require_current_account
        config.require_current_account
      end

      def current_account
        config.current_account
      end

      def api_url_version
        client.server_version
      end

      def client(token = nil, api_url = nil)
        if token.kind_of?(String)
          token = Kontena::Cli::Config::Token.new(access_token: token)
        end

        @client ||= Kontena::Client.new(
          api_url || require_api_url,
          token || require_current_master.token
        )
      end

      def reset_client
        @client = nil
      end

      def settings_filename
        config.config_filename
      end

      def settings
        config
      end

      def api_url
        config.require_current_master.url
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
        config.current_grid=(grid)
      end

      def require_current_grid
        config.require_current_grid
      end

      def clear_current_grid
        current_master.delete_field(:grid) if require_current_master.respond_to?(:grid)
        config.write
      end

      def current_grid
        config.current_grid || (self.respond_to?(:grid) ? self.grid : nil)
      end

      def current_master_index
        config.find_server_index(require_current_master.name)
      end

      def current_master
        config.current_master
      end

      def current_master=(master_alias)
        config.current_master = master_alias
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
        config.current_master.url = api_url
        config.write
      end

      def access_token=(token)
        require_current_master.token.access_token = token
        config.write
      end

      def add_master(server_name, master_info)
        config.add_server(master_info.merge('name' => server_name))
      end

      def any_key_to_continue
        msg = "Press any key to continue or ctrl-c to cancel.. "
        print "#{msg}".colorize(:white)
        char = STDIN.getch
        print "\r#{' ' * msg.length}\r"
        if char == "\u0003"
          puts "Canceled".colorize(:red)
          exit 1
        end
      end

      def display_logo
        logo = <<LOGO
 _               _
| | _____  _ __ | |_ ___ _ __   __ _
| |/ / _ \\| '_ \\| __/ _ \\ '_ \\ / _` |
|   < (_) | | | | ||  __/ | | | (_| |
|_|\\_\\___/|_| |_|\\__\\___|_| |_|\\__,_|
-------------------------------------
Copyright (c)2016 Kontena, Inc.
LOGO
        puts logo
      end

      def display_login_info
        server = config.current_master
        if server
          puts [
            'Authenticated to'.colorize(:green),
            server.name.colorize(:yellow),
            'at'.colorize(:green),
            server.url.colorize(:yellow),
            'as'.colorize(:green),
            server.username.colorize(:yellow)
          ].join(' ')
        else
          puts "Master not selected".colorize(:red)
        end
    end

    end
  end
end

require 'tty-prompt'
require 'pastel'
require 'uri'
require 'io/console'

require_relative 'config'
require_relative 'spinner'

module Kontena
  module Cli
    module Common

      def logger
        return @logger if @logger
        @logger = Logger.new(ENV["DEBUG"] ? $stderr : $stdout)
        @logger.level = ENV["DEBUG"].nil? ? Logger::INFO : Logger::DEBUG
        @logger.progname = 'COMMON'
        @logger
      end

      def pastel
        @pastel ||= Pastel.new(enabled: $stdout.tty?)
      end

      # Read from STDIN. If stdin is a console, use prompt to ask.
      # @param [String] message
      # @param [Symbol] mode (prompt method: :ask, :multiline, etc)
      def stdin_input(message = nil, mode = :ask)
        if $stdin.tty?
          Array(prompt.send(mode, message)).join.chomp
        elsif !$stdin.eof?
          $stdin.read.chomp
        else
          exit_with_error 'Missing input'
        end
      end

      def running_silent?
        self.respond_to?(:silent?) && self.silent?
      end

      def running_verbose?
        self.respond_to?(:verbose?) && self.verbose?
      end

      # Puts that puts even when self.silent?
      def sputs(*msgs)
        ::Kernel.puts(*msgs)
      end

      # Print that prints even when self.silent?
      def sprint(*msgs)
        ::Kernel.print(*msgs)
      end

      # Print that doesn't print if self.silent?
      def print(*msgs)
        if running_silent?
          logger.debug(msgs.join)
        else
          super(*msgs)
        end
      end

      # Puts that doesn't puts if self.silent?
      def puts(*msgs)
        if running_silent?
          msgs.compact.each { |msg| logger.debug(msg) }
        elsif Thread.main['spinners'] && !Thread.main['spinners'].empty?
          Thread.main['spinner_msgs'] ||= []
          msgs.each { |msg| Thread.main['spinner_msgs'] << msg }
        else
          super(*msgs)
        end
      end

      # Only output message if in verbose mode
      def vputs(msg = nil)
        if running_verbose?
          puts msg
        elsif ENV["DEBUG"] && msg
          logger.debug msg
        end
      end

      # Only show spinner when in verbose mode
      def vspinner(msg, &block)
        return vfakespinner(msg) unless block_given?

        if running_verbose?
          spinner(msg, &block)
        else
          yield
        end
      end

      # Like vspinner but without actually running any block
      def vfakespinner(msg, success: true)
        if !running_verbose?
          logger.debug msg
          return
        end
        puts " [#{ success ? 'done'.colorize(:green) : 'fail'.colorize(:red)}] #{msg}"
      end

      def warning(msg)
        warning = pastel.yellow('warn')
        $stderr.puts " [#{warning}] #{msg}"
      end

      def exit_with_error(msg, code = 1)
        error = pastel.red('error')
        $stderr.puts " [#{error}] #{msg}"
        exit code
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

      ## Invalidate refresh_token
      # @param [Kontena::Cli::Config::Server] server
      def use_refresh_token(server)
        return unless server.token
        return unless server.token.refresh_token
        return if server.token.expired?
        client = Kontena::Client.new(server.url, server.token)
        logger.debug "Trying to invalidate refresh token on #{server.name}"
        client.refresh_token
      rescue => ex
        logger.debug "Refreshing failed: #{ex.class.name} : #{ex.message}"
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

      def kontena_account
        @kontena_account ||= config.find_account(ENV['KONTENA_ACCOUNT'] || 'kontena')
      end

      def cloud_auth?
        return false unless kontena_account
        return false unless kontena_account.token
        return false unless kontena_account.token.access_token
        true
      end

      def api_url_version
        client.server_version
      end

      def cloud_client
        @cloud_client ||= Kontena::Client.new(kontena_account.url, kontena_account.token, prefix: '/')
      end

      def reset_cloud_client
        @cloud_client = nil
      end

      def client(token = nil, api_url = nil)
        if token.kind_of?(String)
          token = Kontena::Cli::Config::Token.new(access_token: token)
        end

        @client ||= Kontena::Client.new(
          api_url || require_current_master.url,
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
        (self.respond_to?(:grid) ? self.grid : nil) || config.current_grid
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

      def error(message = "Error")
        prompt.error(message)
        exit(1)
      end

      def ask(question = "")
        prompt.ask(question)
      end

      def yes?(question = "")
        prompt.yes?(question)
      end

      def prompt
        ::Kontena.prompt
      end

      def confirm_command(name, message = nil)
        if self.respond_to?(:force?) && self.force?
          return
        end
        exit_with_error 'Command requires --force' unless $stdout.tty? && $stdin.tty?
        puts message if message
        puts "Destructive command. To proceed, type \"#{name}\" or re-run this command with --force option."

        ask("Enter '#{name}' to confirm: ") == name || error("Confirmation did not match #{name}. Aborted command.")
      end

      def confirm(message = 'Destructive command. You can skip this prompt by running this command with --force option. Are you sure?')
        if self.respond_to?(:force?) && self.force?
          return
        end
        exit_with_error 'Command requires --force' unless $stdout.tty? && $stdin.tty?
        prompt.yes?(message) || error('Aborted command.')
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

      def spinner(msg, &block)
        Kontena::Cli::Spinner.spin(msg, &block)
      end

      def any_key_to_continue_with_timeout(timeout=9)
        return nil if running_silent?
        return nil unless $stdout.tty?
        start_time = Time.now.to_i
        end_time   = start_time + timeout
        Thread.main['any_key.timed_out']   = false
        msg = "Press any key to continue or ctrl-c to cancel.. (Automatically continuing in ? seconds)"

        reader_thread = Thread.new do
          Thread.main['any_key.char'] = $stdin.getch
        end

        countdown_thread = Thread.new do
          time_left = timeout
          while time_left > 0 && Thread.main['any_key.char'].nil?
            print "\r#{pastel.bright_white("#{msg.sub("?", time_left.to_s)}")} "
            time_left = end_time - Time.now.to_i
            sleep 0.1
          end
          print "\r#{' ' * msg.length}  \r"
          reader_thread.kill if reader_thread.alive?
        end

        countdown_thread.join

        if Thread.main['any_key.char'] == "\u0003"
          error "Canceled"
        end
      end

      def any_key_to_continue(timeout = nil)
        return nil if running_silent?
        return nil unless $stdout.tty?
        return any_key_to_continue_with_timeout(timeout) if timeout
        msg = "Press any key to continue or ctrl-c to cancel.. "
        print pastel.bright_cyan("#{msg}")
        char = $stdin.getch
        print "\r#{' ' * msg.length}\r"
        if char == "\u0003"
          error "Canceled"
        end
      end

      def display_account_login_info
        if kontena_account
          if kontena_account.token && kontena_account.token.access_token
            begin
              puts [
                pastel.green("Authenticated to Kontena Cloud at"),
                pastel.yellow(kontena_account.url),
                pastel.green("as"),
                pastel.yellow(kontena_account.username)
              ].join(' ')
            rescue
            end
          else
            puts pastel.cyan("Not authenticated to Kontena Cloud")
          end
        end
      end

      def display_master_login_info
        server = config.current_master
        if server
          if server.token && server.token.access_token
            puts [
              pastel.green('Authenticated to Kontena Master'),
              pastel.yellow(server.name),
              pastel.green('at'),
              pastel.yellow(server.url),
              pastel.green('as'),
              pastel.yellow(server.token.username || server.username)
            ].join(' ')
          else
            puts pastel.cyan("Not authenticated to current master #{server.name}")
          end
        else
          puts pastel.cyan("Current master not selected")
        end
      end

      def display_login_info(only: nil)
        display_master_login_info  unless only == :account
        display_account_login_info unless only == :master
      end

      def display_logo
        puts File.read(File.expand_path('../../../../LOGO', __FILE__))
      end
    end
  end
end

require 'forwardable'
require 'kontena_cli'

module Kontena
  autoload :Client, 'kontena/client'

  module Cli
    autoload :ShellSpinner, 'kontena/cli/spinner'
    autoload :Spinner, 'kontena/cli/spinner'
    autoload :Config, 'kontena/cli/config'

    module Common
      extend Forwardable

      def_delegators :prompt, :ask, :yes?
      def_delegators :config,
        :current_grid=, :require_current_grid, :current_master,
        :current_master=, :require_current_master, :require_current_account,
        :current_account
      def_delegator :config, :config_filename, :settings_filename
      def_delegator :client, :server_version, :api_url_version

      def logger
        Kontena.logger
      end

      def prompt
        Kontena.prompt
      end

      def pastel
        Kontena.pastel
      end

      def spinner(msg, &block)
         Kontena::Cli::Spinner.spin(msg, &block)
      end

      def config
        Kontena::Cli::Config.instance
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

      def running_quiet?
        self.respond_to?(:quiet?) && self.quiet?
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

        if running_verbose? && $stdout.tty?
          spinner(msg, &block)
        else
          logger.debug { msg }
          yield
        end
      end

      # Output a message like: "> Reading foofoo .."
      # @param message [String] the message to display
      # @param dots [TrueClass,FalseClass] set to false if you don't want to add ".." after the message
      def caret(msg, dots: true)
        puts "#{pastel.green('>')} #{msg}#{" #{pastel.green('..')}" if dots}"
      end

      # Run a spinner with a message for the block if a truthy value or a proc returns true.
      # @example
      #   spin_if(proc { prompt.yes?("for real?") }, "Doing as requested") do
      #     # doing stuff
      #   end
      #   spin_if(a == 1, "Value of 'a' is 1, so let's do this") do
      #     # doing stuff
      #   end
      # @param obj_or_proc [Object,Proc] something that responds to .call or is truthy/falsey
      # @param message [String] the message to display
      # @return anything the block returns
      def spin_if(obj_or_proc, message, &block)
        if (obj_or_proc.respond_to?(:call) && obj_or_proc.call) || obj_or_proc
          spinner(message, &block)
        else
          logger.debug { message }
          yield
        end
      end

      # Like vspinner but without actually running any block
      def vfakespinner(msg, success: true)
        if !running_verbose?
          logger.debug { msg }
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
      module_function :exit_with_error

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
        client = Kontena::Client.new(server.url, server.token,
          ssl_cert_path: server.ssl_cert_path,
          ssl_subject_cn: server.ssl_subject_cn,
        )
        logger.debug "Trying to invalidate refresh token on #{server.name}"
        client.refresh_token
      rescue => ex
        logger.debug "Refreshing failed: #{ex.class.name} : #{ex.message}"
      end

      def kontena_account
        @kontena_account ||= config.current_account
      end

      def cloud_auth?
        return false unless kontena_account
        return false unless kontena_account.token
        return false unless kontena_account.token.access_token
        true
      end

      def cloud_client
        @cloud_client ||= Kontena::Client.new(kontena_account.url, kontena_account.token, prefix: '/')
      end

      def reset_cloud_client
        @cloud_client = nil
      end

      def client(token = nil, api_url = nil)
        return @client if @client

        if token.kind_of?(String)
          token = Kontena::Cli::Config::Token.new(access_token: token)
        end

        @client = Kontena::Client.new(
          api_url || require_current_master.url,
          token || require_current_master.token,
          ssl_cert_path: require_current_master.ssl_cert_path,
          ssl_subject_cn: require_current_master.ssl_subject_cn,
        )
      end

      def reset_client
        @client = nil
      end

      def api_url
        config.require_current_master.url
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

      def error(message = "Error")
        prompt.error(message)
        exit(1)
      end

      def confirm_command(name, message = nil)
        if self.respond_to?(:force?) && self.force?
          return
        end
        puts message if message
        exit_with_error 'Command requires --force' unless $stdout.tty? && $stdin.tty?
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

      def any_key_to_continue_with_timeout(timeout=9)
        return nil if running_silent?
        return nil unless $stdout.tty?
        prompt.keypress("Press any key to continue or ctrl-c to cancel (Automatically continuing in :countdown seconds) ...", timeout: timeout)
      end

      def any_key_to_continue(timeout = nil)
        return nil if running_silent?
        return nil unless $stdout.tty?
        return any_key_to_continue_with_timeout(timeout) if timeout
        prompt.keypress("Press any key to continue or ctrl-c to cancel.. ")
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
      module_function :display_logo
    end
  end
end

require 'clamp'
require 'kontena/cli/subcommand_loader'
require 'kontena/util'
require 'kontena/cli/bytes_helper'
require 'kontena/cli/grid_options'
require 'excon/errors'

class Kontena::Command < Clamp::Command

  option ['-D', '--debug'], :flag, "Enable debug", environment_variable: 'DEBUG' do
    ENV['DEBUG'] ||= 'true'
    Kontena.reset_logger
  end

  attr_accessor :arguments
  attr_reader :result
  attr_reader :exit_code

  module Finalizer
    def self.extended(obj)
      # Tracepoint is used to trigger finalize once the command is completely
      # loaded. If done through def self.inherited the finalizer and
      # after_load callbacks would run before the options are defined.
      TracePoint.trace(:end) do |t|
        if obj == t.self
          obj.finalize
          t.disable
        end
      end
    end

    def finalize
      return if self.has_subcommands?
      return if self.callback_matcher

      name_parts = self.name.split('::')[-2, 2]

      unless name_parts.compact.empty?
        # 1: Remove trailing 'Command' from for example AuthCommand
        # 2: Convert the string from CamelCase to under_score
        # 3: Convert the string into a symbol
        #
        # In comes: ['ExternalRegistry', 'UseCommand']
        # Out goes: [:external_registry, :use]
        name_parts = name_parts.map { |np|
          np.gsub(/Command$/, '').
          gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
          gsub(/([a-z\d])([A-Z])/,'\1_\2').
          tr("-", "_").
          downcase.
          to_sym
        }
        self.callback_matcher(*name_parts)
      end

      # Run all #after_load callbacks for this command.
      [name_parts.last, :all].compact.uniq.each do |cmd_type|
        [name_parts.first, :all].compact.uniq.each do |cmd_class|
          if Kontena::Callback.callbacks.fetch(cmd_class, {}).fetch(cmd_type, nil)
            Kontena::Callback.callbacks[cmd_class][cmd_type].each do |cb|
              if cb.instance_methods.include?(:after_load)
                cb.new(self).after_load
              end
            end
          end
        end
      end
    end
  end

  def self.load_subcommand(path)
    Kontena::Cli::SubcommandLoader.new(path)
  end

  def self.inherited(where)
    where.extend Finalizer
  end

  def self.callback_matcher(cmd_class = nil, cmd_type = nil)
    unless cmd_class
      if @command_class.nil?
        return nil
      else
        return [@command_class, @command_type]
      end
    end
    @command_class = cmd_class.to_sym
    @command_type = cmd_type.to_sym
    [@command_class, @command_type]
  end

  def run_callbacks(state)
    if self.class.respond_to?(:callback_matcher) && !self.class.callback_matcher.nil? && !self.class.callback_matcher.compact.empty?
      Kontena::Callback.run_callbacks(self.class.callback_matcher, state, self)
    end
  end

  # Overwrite Clamp's banner command. Calling banner multiple times
  # will now add lines to the banner message instead of overwriting
  # the whole message. This is useful if callbacks add banner messages.
  #
  # @param [String] message
  def self.banner(msg, extra_feed = true)
    self.description = [self.description, extra_feed ? "\n#{msg}" : msg].compact.join("\n")
  end

  def self.requires_current_master
    unless Kontena::Cli::Config.current_master
      banner "#{Kontena.pastel.green("Requires current master")}: This command requires that you have selected a current master using 'kontena master login' or 'kontena master use'. You can also use the environment variable KONTENA_URL to specify the master address or KONTENA_MASTER=master_name to override the current_master setting."
    end
    @requires_current_master = true
  end

  def self.requires_current_grid
    unless Kontena::Cli::Config.current_grid
      banner "#{Kontena.pastel.green("Requires current grid")}: This command requires that you have selected a grid as the current grid using 'kontena grid use' or by setting KONTENA_GRID environment variable."
    end
    @requires_current_grid = true
  end

  def self.requires_current_account_token
    unless Kontena::Cli::Config.current_account && Kontena::Cli::Config.current_account.token && Kontena::Cli::Config.current_account.token.access_token
      banner "#{Kontena.pastel.green("Requires account authentication")}: This command requires that you have authenticated to Kontena Cloud using 'kontena cloud auth'"
    end
    @requires_current_account_token = true
  end


  def self.requires_current_master?
    @requires_current_master ||= false
  end

  def verify_current_master
    Kontena::Cli::Config.instance.require_current_master if self.class.requires_current_master?
  end

  def self.requires_current_grid?
    @requires_current_grid ||= false
  end

  def verify_current_grid
    Kontena::Cli::Config.instance.require_current_grid if self.class.requires_current_grid?
  end

  def self.requires_current_account_token?
    @requires_current_account_token ||= false
  end

  def verify_current_account_token
    retried ||= false
    Kontena::Cli::Config.instance.require_current_account_token if self.class.requires_current_account_token?
  end

  def self.requires_current_master_token
    @requires_current_master_token = true
  end

  def self.requires_current_master_token?
    @requires_current_master_token ||= false
  end

  def verify_current_master_token
    return nil unless self.class.requires_current_master_token?
    retried ||= false
    Kontena::Cli::Config.instance.require_current_master_token
  rescue Kontena::Cli::Config::TokenExpiredError
    server = Kontena::Cli::Config.instance.current_master
    success = Kontena::Client.new(server.url, server.token,
      ssl_cert_path: server.ssl_cert_path,
      ssl_subject_cn: server.ssl_subject_cn,
    ).refresh_token
    if success && !retried
      retried = true
      retry
    else
      raise Kontena::Cli::Config::TokenExpiredError, "The access token has expired and refresh failed. Try authenticating again, use: kontena master login"
    end
  end

  def help_requested?
    return true if @arguments.include?('--help')
    return true if @arguments.include?('-h')
    false
  end

  # Returns an instance of the command, just like with Kontena.run! but before calling "execute"
  # You can use it for specs or reuse of instancemethods.
  # Example:
  #   cmd = Kontena::FooCommand.instance(['-n', 'foo'])
  #   cmd.fetch_stuff
  def instance(arguments)
    @arguments = arguments
    parse @arguments
    self
  end

  def run(arguments)
    Kontena.logger.debug { "Running #{self.class.name} with #{arguments.inspect} -- callback matcher = '#{self.class.callback_matcher.nil? ? "nil" : self.class.callback_matcher.map(&:to_s).join(' ')}'" }
    @arguments = arguments

    run_callbacks :before_parse unless help_requested?

    parse @arguments

    unless help_requested?
      verify_current_master
      verify_current_master_token
      verify_current_grid
      run_callbacks :before
    end

    begin
      @result = execute
      @exit_code = @result.kind_of?(FalseClass) ? 1 : 0
    rescue SystemExit => exc
      @result = exc.status == 0
      @exit_code = exc.status
    end
    run_callbacks :after unless help_requested?
    exit(@exit_code) if @exit_code.to_i > 0
    @result
  rescue Excon::Errors::SocketError => ex
    if ex.message.include?('Unable to verify certificate')
      $stderr.puts " [#{Kontena.pastel.red('error')}] The server uses a certificate signed by an unknown authority."
      $stderr.puts "         You can trust this server by copying server CA pem file to: #{Kontena.pastel.yellow("~/.kontena/certs/<hostname>.pem")}"
      $stderr.puts "         If kontena cannot find your system ca bundle, you can set #{Kontena.pastel.yellow('SSL_CERT_DIR=/etc/ssl/certs')} env variable to load them from another location."
      $stderr.puts "         Protip: you can bypass the certificate check by setting #{Kontena.pastel.yellow('SSL_IGNORE_ERRORS=true')} env variable, but any data you send to the server could be intercepted by others."
      abort
    else
      abort(ex.message)
    end
  rescue Kontena::Errors::StandardError => ex
    raise ex if ENV['DEBUG']
    Kontena.logger.error(ex)
    abort(" [#{Kontena.pastel.red('error')}] #{ex.status} : #{ex.message}")
  rescue Errno::EPIPE
    # If user is piping the command outputs to some other command that might exit before CLI has outputted everything
    abort
  rescue Clamp::HelpWanted, Clamp::UsageError
    raise
  rescue => ex
    raise ex if ENV['DEBUG']
    Kontena.logger.error(ex)
    abort(" [#{Kontena.pastel.red('error')}] #{ex.class.name} : #{ex.message}\n         See #{Kontena.log_target} or run the command again with environment DEBUG=true set to see the full exception")
  end
end

require 'kontena/callback'

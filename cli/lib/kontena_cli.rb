require 'logger'

$KONTENA_START_TIME = Time.now.to_f
at_exit do
  Kontena.logger.debug { "Execution took #{(Time.now.to_f - $KONTENA_START_TIME).round(2)} seconds" }
  Kontena.logger.debug { "#{$!.class.name}" + ($!.respond_to?(:status) ? " status #{$!.status}" : "") } if $!
end

module Kontena
  # Run a kontena command like it was launched from the command line.
  #
  # @example
  #   Kontena.run("grid list --help")
  #
  # @param [String,Array<String>] command_line
  # @return [Fixnum] exit_code
  def self.run(*cmdline, returning: :status)
    if cmdline.first.kind_of?(Array)
      command = cmdline.first
    elsif cmdline.size == 1 && cmdline.first.include?(' ')
      command = cmdline.first.shellsplit
    else
      command = cmdline
    end
    logger.debug { "Running Kontena.run(#{command.inspect}, returning: #{returning}" }
    result = Kontena::MainCommand.new(File.basename(__FILE__)).run(command)
    logger.debug { "Command completed, result: #{result.inspect} status: 0" }
    return 0 if returning == :status
    return result if returning == :result
  rescue SystemExit => ex
    logger.error { "Command completed with failure, result: #{result.inspect} status: #{ex.status}" }
    returning == :status ? $!.status : nil
  rescue => ex
    logger.error(ex)
    returning == :status ? 1 : nil
  end

  def self.log_target
    return @log_target if @log_target

    @log_target = ENV["LOG_TARGET"]

    if ENV["DEBUG"]
      @log_target ||= $stderr
    elsif @log_target.nil?
      @log_target = File.join(home, 'kontena.log')
    end
  end

  def self.home
    return @home if @home
    @home = File.join(Dir.home, '.kontena')
    Dir.mkdir(@home, 0700) unless File.directory?(@home)
    @home
  end

  # @return [String] x.y
  def self.minor_version
    Kontena::Cli::VERSION.split('.')[0..1].join('.')
  end

  def self.version
    "kontena-cli/#{Kontena::Cli::VERSION}"
  end

  def self.on_windows?
    ENV['OS'] == 'Windows_NT' && RUBY_PLATFORM !~ /cygwin/
  end

  def self.browserless?
    !!(RUBY_PLATFORM =~ /linux|(?:free|net|open)bsd|solaris|aix|hpux/ && ENV['DISPLAY'].to_s.empty?)
  end

  def self.simple_terminal?
    ENV['KONTENA_SIMPLE_TERM'] || !$stdout.tty?
  end

  def self.pastel
    return @pastel if @pastel
    require 'pastel'
    @pastel = Pastel.new(enabled: !simple_terminal?)
  end

  def self.prompt
    return @prompt if @prompt
    if simple_terminal?
      require_relative 'kontena/light_prompt'
      klass = Kontena::LightPrompt
    else
      require 'tty-prompt'
      klass = TTY::Prompt
    end

    @prompt = klass.new(
      active_color: :cyan,
      help_color: :white,
      error_color: :red,
      interrupt: :exit,
      prefix: pastel.green('> ')
    )
  end

  def self.reset_prompt
    @prompt = nil
  end

  def self.root
    File.dirname(__dir__)
  end

  def self.cli_root(*joinables)
    if joinables.empty?
      File.join(Kontena.root, 'lib/kontena/cli')
    else
      File.join(Kontena.root, 'lib/kontena/cli', *joinables)
    end
  end

  def self.logger
    return @logger if @logger
    if log_target.respond_to?(:tty?) && log_target.tty?
      @logger = Logger.new(log_target)
    else
      @logger = Logger.new(log_target, 1, 65536)
      @logger.formatter = ColorStrippingFormatter.new
    end
    @logger.level = ENV["DEBUG"] ? Logger::DEBUG : Logger::INFO
    @logger.progname = 'CLI'
    @logger
  end

  class ColorStrippingFormatter < Logger::Formatter
    def msg2str(msg)
      msg.gsub!(/\e+\[{1,2}[0-9;:?]+m/m, '') if msg.kind_of?(String)
      super(msg)
    end
  end
end

# Monkeypatching string to mimick 'colorize' gem
class String
  def colorize(color_sym)
    ::Kontena.pastel.send(color_sym, self)
  end
end

require 'retriable'
Retriable.configure do |c|
  c.on_retry = Proc.new do |exception, try, elapsed_time, next_interval|
    return true unless ENV["DEBUG"]
    puts "Retriable retry: #{try} - Exception: #{exception.class.name} - #{exception.message}. Elapsed: #{elapsed_time} Next interval: #{next_interval}"
  end
end

require 'ruby_dig'
require 'shellwords'
require "safe_yaml"
SafeYAML::OPTIONS[:default_mode] = :safe
require 'kontena/cli/version'
Kontena.logger.debug { "Kontena CLI #{Kontena::Cli::VERSION} (ruby-#{RUBY_VERSION}+#{RUBY_PLATFORM})" }
require 'kontena/cli/common'
require 'kontena/command'
require 'kontena/client'
require 'kontena/stacks_cache'
require 'kontena/plugin_manager'
require 'kontena/main_command'
require 'kontena/cli/spinner'

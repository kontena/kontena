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
    ENV["DEBUG"] && puts("Running Kontena.run(#{command.inspect}, returning: #{returning}")
    result = Kontena::MainCommand.new(File.basename(__FILE__)).run(command)
    ENV["DEBUG"] && puts("Command completed, result: #{result.inspect} status: 0")
    return 0 if returning == :status
    return result if returning == :result
  rescue SystemExit => ex
    ENV["DEBUG"] && $stderr.puts("Command completed with failure, result: #{result.inspect} status: #{ex.status}")
    returning == :status ? $!.status : nil
  rescue => ex
    ENV["DEBUG"] && $stderr.puts("Command raised #{ex} with message: #{ex.message}\n#{ex.backtrace.join("\n  ")}")
    returning == :status ? 1 : nil
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
    @pastel ||= Pastel.new(enabled: !simple_terminal?)
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
require_relative 'kontena/cli/version'
require_relative 'kontena/cli/common'
require_relative 'kontena/command'
require_relative 'kontena/client'
require_relative 'kontena/stacks_cache'
require_relative 'kontena/plugin_manager'
require_relative 'kontena/main_command'
require_relative 'kontena/cli/spinner'

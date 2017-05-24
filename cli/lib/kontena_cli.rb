begin
  unless Gem.loaded_specs.include?('kontena-cli')
    load File.expand_path('../../kontena-cli.gemspec', __FILE__)
    KONTENA_CLI.activate
    KONTENA_CLI.activate_dependencies
  end
rescue LoadError
end

module Kontena
  # Run a kontena command like it was launched from the command line. Re-raises any exceptions,
  # except a SystemExit with status 0, which is considered a success.
  #
  # @param [String,Array<String>] command_line
  # @return command result or nil
  def self.run!(*cmdline)
    if cmdline.first.kind_of?(Array)
      command = cmdline.first
    elsif cmdline.size == 1 && cmdline.first.include?(' ')
      command = cmdline.first.shellsplit
    else
      command = cmdline
    end
    ENV["DEBUG"] && puts("Running Kontena.run(#{command.inspect}")
    result = Kontena::MainCommand.new(File.basename(__FILE__)).run(command)
    ENV["DEBUG"] && puts("Command completed, result: #{result.inspect} status: 0")
    result
  rescue SystemExit => ex
    ENV["DEBUG"] && $stderr.puts("Command caused SystemExit, result: #{result.inspect} status: #{ex.status}")
    return true if ex.status.zero?
    raise ex
  rescue => ex
    ENV["DEBUG"] && $stderr.puts("Command raised #{ex.class.name} with message: #{ex.message}\n#{ex.backtrace.join("\n  ")}")
    raise ex
  end

  # Run a kontena command and return true if the command did not raise or exit with a non-zero exit code. Raises nothing.
  # @param [String,Array<String>] command_line
  # @return [TrueClass,FalseClass] success
  def self.run(*cmdline)
    result = run!(*cmdline)
    result.nil? ? true : result
  rescue SystemExit => ex
    ex.status.zero?
  rescue
    false
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
require 'kontena/cli/version'
require 'kontena/cli/common'
require 'kontena/command'
require 'kontena/client'
require 'kontena/stacks_cache'
require 'kontena/plugin_manager'
require 'kontena/main_command'
require 'kontena/cli/spinner'

module Kontena
  # Run a kontena command like it was launched from the command line.
  # 
  # @example
  #   Kontena.run("grid list --help")
  #
  # @param [String] command_line 
  # @return [Fixnum] exit_code
  def self.run(cmdline = "", returning: :status)
    ENV["DEBUG"] && puts("Running Kontena.run(#{cmdline.inspect}, returning: #{returning}")
    result = Kontena::MainCommand.new(File.basename(__FILE__)).run(cmdline.shellsplit)
    ENV["DEBUG"] && puts("Command completed, result: #{result.inspect} status: 0")
    return 0 if returning == :status
    return result if returning == :result
  rescue SystemExit
    ENV["DEBUG"] && puts("Command completed with failure, result: #{result.inspect} status: #{$!.status}")
    returning == :status ? $!.status : nil
  rescue
    ENV["DEBUG"] && puts("Command raised #{$!} with message: #{$!.message}\n  #{$!.backtrace.join("  \n")}")
    returning == :status ? 1 : nil
  end
    

  def self.version
    "kontena-cli/#{Kontena::Cli::VERSION}"
  end

  def self.pastel
    @pastel ||= Pastel.new(enabled: $stdout.tty?)
  end

  def self.prompt
    @prompt ||= TTY::Prompt.new(
      active_color: :cyan,
      help_color: :white,
      error_color: :red,
      interrupt: :exit,
      prefix: pastel.green('> ')
    )
  end

  def self.root
    File.dirname(__dir__)
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
    puts "Retriable retry: #{try} - Exception: #{exception} - #{exception.message}. Elapsed: #{elapsed_time} Next interval: #{next_interval}"
  end
end

require 'ruby_dig'
require 'shellwords'
require_relative 'kontena/cli/version'
require_relative 'kontena/cli/common'
require_relative 'kontena/command'
require_relative 'kontena/client'
require_relative 'kontena/stacks_cache'
require_relative 'kontena/plugin_manager'
require_relative 'kontena/main_command'
require_relative 'kontena/cli/spinner'


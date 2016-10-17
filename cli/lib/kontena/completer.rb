require File.expand_path('../../kontena_cli', __FILE__)

module Kontena
  class Completer

    attr_reader :command
    attr_reader :main_command

    def initialize(words = [])
      cmd_name  = words.shift || 'kontena'
      @main_command = Kontena::MainCommand.new(cmd_name)
      @main_command.parse(words)
    end

    def recurse_subcommand(cmd)
      return cmd unless cmd.class.has_subcommands?
      begin 
        return cmd if cmd.subcommand_name.nil?
      rescue
        return cmd
      end

      begin
        new_cmd = cmd.send(:instatiate_subcommand, cmd.subcommand_name)
      rescue
        if cmd.subcommand_arguments.empty?
          cmd.instance_eval do
            @remaining_arguments = [cmd.subcommand_name]
          end
        end
        return cmd
      end

      begin
        new_cmd.parse(cmd.subcommand_arguments)
      rescue
        new_cmd.instance_eval do
          @remaining_arguments = cmd.subcommand_arguments
        end
        return new_cmd
      end

      recurse_subcommand(new_cmd)
    end

    def run
      @command = recurse_subcommand(main_command)
      parse
    rescue
      if ENV["DEBUG_COMPLETER"]
        STDERR.puts($!)
        STDERR.puts($!.message)
        STDERR.puts($!.backtrace)
      end
      nil
    end

    def parse
      if command.class.has_subcommands?
        list_subcommands
      else
        parse_partial
      end
    end

    def parse_partial
      arg = command.remaining_arguments.first
      if arg && arg.start_with?('-')
        results = list_options
        if results.size == 1 && results.first == arg
          arg_name = arg.gsub(/^\-{1,}/, '')
          method = "complete_#{arg_name}".to_sym
          if command.respond_to?(method)
            command.send(method, command.remaining_arguments[1])
          else
            []
          end
        else
          list_options
        end
      elsif command.respond_to?(:complete)
        command.complete(arg) rescue []
      else
        []
      end
    end

    def list_options
      options.select{|switch| switch.start_with?(command.remaining_arguments.first)}
    end

    def options
      command.class.recognised_options.map(&:switches).flatten
    end

    def list_subcommands
      if command.remaining_arguments.empty?
        subcommands
      else
        subcommands.select{ |name| name.start_with?(command.remaining_arguments.first) }
      end
    end

    def subcommands
      command.class.recognised_subcommands.map(&:names).flatten
    end
  end
end


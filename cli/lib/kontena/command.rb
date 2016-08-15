require 'clamp'

class Kontena::Command < Clamp::Command

  class Hook
    attr_reader :arguments
    attr_reader :outcome

    def initialize(arguments = nil, outcome = nil)
      @arguments = arguments
      @outcome   = outcome
    end
  end

  def self.command_type(cmd_type = nil)
    return @command_type unless cmd_type
    @command_type = cmd_type
  end

  def pre_command_hook(command_type, arguments)
    cmd_type = "#{command_type}_hook".split('_').collect(&:capitalize).join
    if Kontena::Command::Hook::const_defined?(cmd_type)
      arguments = Kontena::Command::Hook::const_get(cmd_type).new(arguments).before
      if arguments.kind_of?(FalseClass)
        puts "Execution aborted by #{cmd_type}"
        exit 1
      end
    end
    arguments
  end

  def post_command_hook(command_type, arguments, outcome)
    cmd_type = "#{command_type}_hook".split('_').collect(&:capitalize).join
    if Kontena::Command::Hook::const_defined?(cmd_type)
      outcome = Kontena::Command::Hook::const_get(cmd_type).new(arguments, outcome).after
    end
    outcome
  end

  def run(arguments)
    if self.class.respond_to?(:command_type)
      arguments = pre_command_hook(self.class.command_type, arguments)
    end
    outcome = super(arguments)
    if self.class.respond_to?(:command_type)
      outcome = post_command_hook(self.class.command_type, arguments, outcome)
    end
    outcome
  end
end

Dir[File.expand_path('../hooks/*.rb', __FILE__)].each { |file| require file }

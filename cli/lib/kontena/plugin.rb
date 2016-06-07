module Kontena
  class Plugin
    attr_reader :command, :description, :command_class

    def initialize(command, description, command_class)
      @command = command
      @description = description
      @command_class = command_class
    end
  end
end

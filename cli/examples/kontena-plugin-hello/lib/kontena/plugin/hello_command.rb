require_relative 'hello/world_command'

class Kontena::Plugin::HelloCommand < Kontena::Command
  subcommand 'world', 'Hello world related commands', Kontena::Plugin::Hello::WorldCommand
end

require_relative 'world/test_command'

class Kontena::Plugin::HelloCommand < Kontena::Command

  subcommand 'world', 'Hello world related commands', Kontena::Plugin::Hello::TestCommand

  def execute
  end
end

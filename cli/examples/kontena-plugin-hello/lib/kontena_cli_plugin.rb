require 'kontena_cli'
require_relative 'kontena/plugin/hello'
require_relative 'kontena/plugin/hello_command'

Kontena::MainCommand.register("hello", "Hello specific commands", Kontena::Plugin::HelloCommand)

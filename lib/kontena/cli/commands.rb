require 'kontena/cli/version'

module Kontena::Cli; end;

program :name, 'kontena'
program :version, Kontena::Cli::VERSION
program :description, 'Command line interface for Kontena.io'

default_command :help
never_trace!

require_relative 'platform/commands'
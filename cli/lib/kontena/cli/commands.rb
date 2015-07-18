require 'kontena/cli/version'

module Kontena::Cli; end;

program :name, 'kontena'
program :version, Kontena::Cli::VERSION
program :description, 'Command line interface for Kontena.'
program :int_block do
  exit 1
end

default_command :help
never_trace!

require_relative 'server/commands'
require_relative 'containers/commands'
require_relative 'grids/commands'
require_relative 'nodes/commands'
require_relative 'services/commands'
require_relative 'stacks/commands'

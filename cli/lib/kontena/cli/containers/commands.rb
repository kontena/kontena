module Kontena::Cli::Containers; end;

require_relative 'containers'


command 'container exec' do |c|
  c.syntax = 'kontena container exec <container_id> <cmd>'
  c.description = 'Execute command inside container'
  c.action do |args, options|
    Kontena::Cli::Containers::Containers.new.exec(args[0], args[1])
  end
end

module Kontena::Cli::Nodes; end;

require_relative 'nodes'

command 'node list' do |c|
  c.syntax = 'kontena node list'
  c.description = 'List all nodes'
  c.action do |args, options|
    Kontena::Cli::Nodes::Nodes.new.list
  end
end

command 'node show' do |c|
  c.syntax = 'kontena node show'
  c.description = 'Show node details'
  c.action do |args, options|
    Kontena::Cli::Nodes::Nodes.new.show(args[0])
  end
end

command 'node update' do |c|
  c.syntax = 'kontena node update'
  c.description = 'Update node'
  c.option '--labels Array', Array, 'Node labels'
  c.action do |args, options|
    Kontena::Cli::Nodes::Nodes.new.update(args[0], options)
  end
end

command 'node remove' do |c|
  c.syntax = 'kontena node remove'
  c.description = 'Remove node'
  c.action do |args, options|
    Kontena::Cli::Nodes::Nodes.new.destroy(args[0])
  end
end

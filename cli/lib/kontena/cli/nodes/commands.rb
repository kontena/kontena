module Kontena::Cli::Nodes; end;

require_relative 'nodes'
require_relative 'digital_ocean'

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
  c.description = 'Remove node from grid'
  c.action do |args, options|
    Kontena::Cli::Nodes::Nodes.new.destroy(args[0])
  end
end

command 'node create digitalocean' do |c|
  c.syntax = 'node create digitalocean'
  c.description = 'Create node to DigitalOcean'
  c.option '--token STRING', String, 'DO token'
  c.option '--ssh-key STRING', String, 'Path to ssh public key'
  c.option '--name STRING', String, 'Node name'
  c.option '--size STRING', String, 'Droplet size (default: 1gb)'
  c.option '--region STRING', String, 'Region (default: ams3)'
  c.action do |args, options|
    raise ArgumentError.new('--token is required') unless options.token
    raise ArgumentError.new('--ssh-key is required') unless options.ssh_key
    Kontena::Cli::Nodes::DigitalOcean.new.provision(options)
  end
end

command 'node terminate digitalocean' do |c|
  c.syntax = 'node terminate digitalocean <name>'
  c.description = 'Terminate node from DigitalOcean'
  c.option '--token STRING', String, 'DO token'
  c.action do |args, options|
    raise ArgumentError.new('--token is required') unless options.token
    Kontena::Cli::Nodes::DigitalOcean.new.destroy(args[0], options.token)
  end
end

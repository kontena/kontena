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

command 'node remove' do |c|
  c.syntax = 'kontena node remove'
  c.description = 'Remove node'
  c.action do |args, options|
    Kontena::Cli::Nodes::Nodes.new.destroy(args[0])
  end
end

command 'node provision digitalocean' do |c|
  c.syntax = 'node provision do'
  c.description = 'Provision grid nodes'
  c.option '--token STRING', String, 'DO token'
  c.option '--ssh-key STRING', String, 'Path to ssh public key'
  c.option '--size STRING', String, 'Droplet size (default: 1gb)'
  c.option '--region STRING', String, 'Region (default: ams3)'
  c.action do |args, options|
    raise ArgumentError.new('--token is required') unless options.token
    raise ArgumentError.new('--ssh-key is required') unless options.ssh_key
    Kontena::Cli::Nodes::DigitalOcean.new.provision(options)
  end
end

command 'node destroy digitalocean' do |c|
  c.syntax = 'node destroy digitalocean'
  c.description = 'Destroy node'
  c.option '--name STRING', String, 'Node name'
  c.option '--token STRING', String, 'DO token'
  c.action do |args, options|
    raise ArgumentError.new('--token is required') unless options.token
    Kontena::Cli::Nodes::DigitalOcean.new.destroy(options)
  end
end

module Kontena::Cli::Platform; end;

require_relative 'user'
require_relative 'api'
require_relative 'grids'
require_relative 'nodes'
require_relative 'services'

command 'connect' do |c|
  c.syntax = 'kontena connect <url>'
  c.description = 'Connect to Kontena server'
  c.action do |args, options|
    Kontena::Cli::Platform::Api.new.connect(args[0])
  end
end

command 'disconnect' do |c|
  c.syntax = 'kontena disconnect'
  c.description = 'Disconnect from Kontena server'
  c.action do |args, options|
    Kontena::Cli::Platform::Api.new.disconnect
  end
end

command 'grids' do |c|
  c.syntax = 'kontena grids'
  c.description = 'List all grids'
  c.action do |args, options|
    Kontena::Cli::Platform::Grids.new.list
  end
end

command 'grids use' do |c|
  c.syntax = 'kontena grids use <name>'
  c.description = 'Switch to use specific grid'
  c.action do |args, options|
    raise ArgumentError.new('grid name is required. For a list of existing grids please run: kontena grids') if args[0].nil?
    Kontena::Cli::Platform::Grids.new.use(args[0])
  end
end

command 'grids show' do |c|
  c.syntax = 'kontena grid show <name>'
  c.description = 'Show grid details'
  c.action do |args, options|
    raise ArgumentError.new('grid name is required. For a list of existing grids please run: kontena grids') if args[0].nil?
    Kontena::Cli::Platform::Grids.new.show(args[0])
  end
end

command 'grids current' do |c|
  c.syntax = 'kontena grids show <name>'
  c.description = 'Show current grid details'
  c.action do |args, options|
    Kontena::Cli::Platform::Grids.new.current
  end
end

command 'grids audit_log' do |c|
  c.syntax = 'kontena grids audit_log'
  c.description = 'Show audit log of the current grid'
  c.option '-l', '--limit INTEGER', Integer, 'Number of lines'
  c.action do |args, options|
    Kontena::Cli::Platform::Grids.new.audit_log(options)
  end
end

command 'grids create' do |c|
  c.syntax = 'kontena grids create <name>'
  c.description = 'Create a new grid'
  c.action do |args, options|
    Kontena::Cli::Platform::Grids.new.create(args[0])
  end
end

command 'grids remove' do |c|
  c.syntax = 'kontena grids remove <name>'
  c.description = 'Removes grid'
  c.action do |args, options|
    Kontena::Cli::Platform::Grids.new.destroy(args[0])
  end
end

command 'nodes' do |c|
  c.syntax = 'kontena nodes'
  c.description = 'List all nodes'
  c.action do |args, options|
    Kontena::Cli::Platform::Nodes.new.list
  end
end


command 'service' do |c|
  c.syntax = 'kontena services'
  c.description = 'List all services'
  c.action do |args, options|
    Kontena::Cli::Platform::Services.new.list
  end
end

command 'service show' do |c|
  c.syntax = 'kontena service show <service_id>'
  c.description = 'Show service details'
  c.action do |args, options|
    Kontena::Cli::Platform::Services.new.show(args[0])
  end
end

command 'service update' do |c|
  c.syntax = 'kontena service update <service_id>'
  c.description = 'Update service'
  c.option '-p', '--ports Array', Array, 'Exposed ports'
  c.option '-e', '--env Array', Array, 'Environment variables'
  c.option '-c', '--containers INTEGER', Integer, 'Containers count'
  c.action do |args, options|
    Kontena::Cli::Platform::Services.new.update(args[0], options)
  end
end

command 'service containers' do |c|
  c.syntax = 'kontena service containers <service_id>'
  c.description = 'Show service containers'
  c.action do |args, options|
    Kontena::Cli::Platform::Services.new.containers(args[0])
  end
end

command 'service logs' do |c|
  c.syntax = 'kontena service logs <service_id>'
  c.description = 'Show service logs'
  c.action do |args, options|
    Kontena::Cli::Platform::Services.new.logs(args[0])
  end
end

command 'service deploy' do |c|
  c.syntax = 'kontena service deploy <service_id>'
  c.description = 'Deploy service to nodes'
  c.action do |args, options|
    Kontena::Cli::Platform::Services.new.deploy(args[0])
  end
end

command 'service create' do |c|
  c.syntax = 'kontena service create <name> <image>'
  c.description = 'Create new service'
  c.option '-p', '--ports Array', Array, 'Publish a service\'s port to the host'
  c.option '-e', '--env Array', Array, 'Set environment variables'
  c.option '-l', '--link Array', Array, 'Add link to another service in the form of name:alias'
  c.option '-c', '--cpu-shares INTEGER', Integer, 'CPU shares (relative weight)'
  c.option '-m', '--memory INTEGER', String, 'Memory limit (format: <number><optional unit>, where unit = b, k, m or g)'
  c.option '--memory-swap INTEGER', String, 'Total memory usage (memory + swap), set \'-1\' to disable swap (format: <number><optional unit>, where unit = b, k, m or g)'
  c.option '-C', '--containers INTEGER', Integer, 'Set containers count'
  c.option '--stateful', 'Set service as stateful'

  c.action do |args, options|
    Kontena::Cli::Platform::Services.new.create(args[0], args[1], options)
  end
end

command 'service delete' do |c|
  c.syntax = 'kontena service delete <service_id>'
  c.description = 'Delete service'
  c.action do |args, options|
    Kontena::Cli::Platform::Services.new.destroy(args[0])
  end
end

command 'service stats' do |c|
  c.syntax = 'kontena service stats <name>'
  c.description = 'Show service stats'
  c.action do |args, options|
    Kontena::Cli::Platform::Services.new.stats(args[0])
  end
end

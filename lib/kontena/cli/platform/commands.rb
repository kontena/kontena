module Kontena::Cli::Platform; end;

require_relative 'user'
require_relative 'api'
require_relative 'grids'
require_relative 'nodes'
require_relative 'services'
require_relative 'users'
require_relative 'containers'

command 'connect' do |c|
  c.syntax = 'kontena connect <url>'
  c.description = 'Connect to Kontena server'
  c.option '--register', 'Register a new user account'
  c.action do |args, options|
    Kontena::Cli::Platform::Api.new.connect(args[0], options)
  end
end

command 'disconnect' do |c|
  c.syntax = 'kontena disconnect'
  c.description = 'Disconnect from Kontena server'
  c.action do |args, options|
    Kontena::Cli::Platform::Api.new.disconnect
  end
end

command 'grid list' do |c|
  c.syntax = 'kontena grid list'
  c.description = 'List all grids'
  c.action do |args, options|
    Kontena::Cli::Platform::Grids.new.list
  end
end

command 'grid use' do |c|
  c.syntax = 'kontena grid use <name>'
  c.description = 'Switch to use specific grid'
  c.action do |args, options|
    raise ArgumentError.new('grid name is required. For a list of existing grids please run: kontena grids') if args[0].nil?
    Kontena::Cli::Platform::Grids.new.use(args[0])
  end
end

command 'grid show' do |c|
  c.syntax = 'kontena grid show <name>'
  c.description = 'Show grid details'
  c.action do |args, options|
    raise ArgumentError.new('grid name is required. For a list of existing grids please run: kontena grids') if args[0].nil?
    Kontena::Cli::Platform::Grids.new.show(args[0])
  end
end

command 'grid current' do |c|
  c.syntax = 'kontena grid current'
  c.description = 'Show current grid details'
  c.action do |args, options|
    Kontena::Cli::Platform::Grids.new.current
  end
end

command 'grid audit_log' do |c|
  c.syntax = 'kontena grid audit_log'
  c.description = 'Show audit log of the current grid'
  c.option '-l', '--limit INTEGER', Integer, 'Number of lines'
  c.action do |args, options|
    Kontena::Cli::Platform::Grids.new.audit_log(options)
  end
end

command 'grid create' do |c|
  c.syntax = 'kontena grid create <name>'
  c.description = 'Create a new grid'
  c.action do |args, options|
    Kontena::Cli::Platform::Grids.new.create(args[0])
  end
end

command 'grid remove' do |c|
  c.syntax = 'kontena grid remove <name>'
  c.description = 'Removes grid'
  c.action do |args, options|
    Kontena::Cli::Platform::Grids.new.destroy(args[0])
  end
end

command 'grid list-users' do |c|
  c.syntax = 'kontena grid list-users'
  c.description = 'Show grid users'
  c.action do |args, options|
    Kontena::Cli::Platform::Users.new.list
  end
end

command 'grid add-user' do |c|
  c.syntax = 'kontena grid add-user <email>'
  c.description = 'Assign user to grid'
  c.action do |args, options|
    Kontena::Cli::Platform::Users.new.add(args[0])
  end
end

command 'grid remove-user' do |c|
  c.syntax = 'kontena grid remove-user <email>'
  c.description = 'Unassign user from grid'
  c.action do |args, options|
    Kontena::Cli::Platform::Users.new.remove(args[0])
  end
end

command 'node list' do |c|
  c.syntax = 'kontena node list'
  c.description = 'List all nodes'
  c.action do |args, options|
    Kontena::Cli::Platform::Nodes.new.list
  end
end

command 'node show' do |c|
  c.syntax = 'kontena node show'
  c.description = 'Show node details'
  c.action do |args, options|
    Kontena::Cli::Platform::Nodes.new.show(args[0])
  end
end

command 'node remove' do |c|
  c.syntax = 'kontena node remove'
  c.description = 'Remove node'
  c.action do |args, options|
    Kontena::Cli::Platform::Nodes.new.destroy(args[0])
  end
end

command 'service list' do |c|
  c.syntax = 'kontena service list'
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

command 'service restart' do |c|
  c.syntax = 'kontena service restart <service_id>'
  c.description = 'Restart service containers'
  c.action do |args, options|
    Kontena::Cli::Platform::Services.new.restart(args[0])
  end
end

command 'service stop' do |c|
  c.syntax = 'kontena service stop <service_id>'
  c.description = 'Stop service containers'
  c.action do |args, options|
    Kontena::Cli::Platform::Services.new.stop(args[0])
  end
end

command 'service start' do |c|
  c.syntax = 'kontena service start <service_id>'
  c.description = 'Start service containers'
  c.action do |args, options|
    Kontena::Cli::Platform::Services.new.start(args[0])
  end
end

command 'service create' do |c|
  c.syntax = 'kontena service create <name> <image>'
  c.description = 'Create new service'
  c.option '-p', '--ports Array', Array, 'Publish a service\'s port to the host'
  c.option '-e', '--env Array', Array, 'Set environment variables'
  c.option '-l', '--link Array', Array, 'Add link to another service in the form of name:alias'
  c.option '-a', '--affinity Array', Array, 'Set service affinity'
  c.option '-c', '--cpu-shares INTEGER', Integer, 'CPU shares (relative weight)'
  c.option '-m', '--memory INTEGER', String, 'Memory limit (format: <number><optional unit>, where unit = b, k, m or g)'
  c.option '--memory-swap INTEGER', String, 'Total memory usage (memory + swap), set \'-1\' to disable swap (format: <number><optional unit>, where unit = b, k, m or g)'
  c.option '--cmd STRING', String, 'Command to execute'
  c.option '--instances INTEGER', Integer, 'How many instances should be deployed'
  c.option '-u', '--user String', String, 'Username who executes first process inside container'
  c.option '--stateful', 'Set service as stateful'

  c.action do |args, options|
    Kontena::Cli::Platform::Services.new.create(args[0], args[1], options)
  end
end

command 'service update' do |c|
  c.syntax = 'kontena service update <service_id>'
  c.description = 'Update service'
  c.option '-p', '--ports Array', Array, 'Exposed ports'
  c.option '-e', '--env Array', Array, 'Environment variables'
  c.option '--instances INTEGER', Integer, 'How many instances should be deployed'
  c.option '--cmd STRING', String, 'Command to execute'
  c.action do |args, options|
    Kontena::Cli::Platform::Services.new.update(args[0], options)
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

command 'container exec' do |c|
  c.syntax = 'kontena container exec <container_id> <cmd>'
  c.description = 'Execute command inside container'
  c.action do |args, options|
    Kontena::Cli::Platform::Containers.new.exec(args[0], args[1])
  end
end

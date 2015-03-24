module Kontena::Cli::Services; end;

require_relative 'containers'
require_relative 'logs'
require_relative 'services'
require_relative 'stats'

command 'service list' do |c|
  c.syntax = 'kontena service list'
  c.description = 'List all services'
  c.action do |args, options|
    Kontena::Cli::Services::Services.new.list
  end
end

command 'service show' do |c|
  c.syntax = 'kontena service show <service_id>'
  c.description = 'Show service details'
  c.action do |args, options|
    Kontena::Cli::Services::Services.new.show(args[0])
  end
end

command 'service deploy' do |c|
  c.syntax = 'kontena service deploy <service_id>'
  c.description = 'Deploy service to nodes'
  c.action do |args, options|
    Kontena::Cli::Services::Services.new.deploy(args[0])
  end
end

command 'service restart' do |c|
  c.syntax = 'kontena service restart <service_id>'
  c.description = 'Restart service containers'
  c.action do |args, options|
    Kontena::Cli::Services::Services.new.restart(args[0])
  end
end

command 'service stop' do |c|
  c.syntax = 'kontena service stop <service_id>'
  c.description = 'Stop service containers'
  c.action do |args, options|
    Kontena::Cli::Services::Services.new.stop(args[0])
  end
end

command 'service start' do |c|
  c.syntax = 'kontena service start <service_id>'
  c.description = 'Start service containers'
  c.action do |args, options|
    Kontena::Cli::Services::Services.new.start(args[0])
  end
end

command 'service create' do |c|
  c.syntax = 'kontena service create <name> <image>'
  c.description = 'Create new service'
  c.option '-p', '--ports Array', Array, 'Publish a service\'s port to the host'
  c.option '-e', '--env Array', Array, 'Set environment variables'
  c.option '-l', '--link Array', Array, 'Add link to another service in the form of name:alias'
  c.option '-v', '--volume Array', Array, 'Mount a volume'
  c.option '--volumes_from Array', Array, 'Mount volumes from another container'
  c.option '-a', '--affinity Array', Array, 'Set service affinity'
  c.option '-c', '--cpu-shares INTEGER', Integer, 'CPU shares (relative weight)'
  c.option '-m', '--memory INTEGER', String, 'Memory limit (format: <number><optional unit>, where unit = b, k, m or g)'
  c.option '--memory-swap INTEGER', String, 'Total memory usage (memory + swap), set \'-1\' to disable swap (format: <number><optional unit>, where unit = b, k, m or g)'
  c.option '--cmd STRING', String, 'Command to execute'
  c.option '--instances INTEGER', Integer, 'How many instances should be deployed'
  c.option '-u', '--user String', String, 'Username who executes first process inside container'
  c.option '--stateful', 'Set service as stateful'

  c.action do |args, options|
    Kontena::Cli::Services::Services.new.create(args[0], args[1], options)
  end
end

command 'service update' do |c|
  c.syntax = 'kontena service update <service_id>'
  c.description = 'Update service'
  c.option '-p', '--ports Array', Array, 'Exposed ports'
  c.option '-e', '--env Array', Array, 'Environment variables'
  c.option '--image STRING', String, 'Service image'
  c.option '--instances INTEGER', Integer, 'How many instances should be deployed'
  c.option '--cmd STRING', String, 'Command to execute'
  c.action do |args, options|
    Kontena::Cli::Services::Services.new.update(args[0], options)
  end
end

command 'service scale' do |c|
  c.syntax = 'kontena service scale <service_id> <instances>'
  c.description = 'Scale service horizontally'
  c.action do |args, options|
    Kontena::Cli::Services::Services.new.scale(args[0], args[1])
  end
end

command 'service delete' do |c|
  c.syntax = 'kontena service delete <service_id>'
  c.description = 'Delete service'
  c.action do |args, options|
    Kontena::Cli::Services::Services.new.destroy(args[0])
  end
end

command 'service containers' do |c|
  c.syntax = 'kontena service containers <service_id>'
  c.description = 'Show service containers'
  c.action do |args, options|
    Kontena::Cli::Services::Containers.new.list(args[0])
  end
end

command 'service logs' do |c|
  c.syntax = 'kontena service logs <service_id>'
  c.description = 'Show service logs'
  c.option '-f', '--follow', 'Follow logs in real time'
  c.action do |args, options|
    Kontena::Cli::Services::Logs.new.show(args[0], options)
  end
end

command 'service stats' do |c|
  c.syntax = 'kontena service stats <name>'
  c.description = 'Show service stats'
  c.option '-f', '--follow', 'Follow stats in real time'
  c.action do |args, options|
    Kontena::Cli::Services::Stats.new.show(args[0], options)
  end
end

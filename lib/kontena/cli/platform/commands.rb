module Kontena::Cli::Platform; end;

require_relative 'user'
require_relative 'api'
require_relative 'grids'
require_relative 'services'

command 'connect' do |c|
  c.syntax = 'kontena connect'
  c.description = 'Connect to Kontena server'
  c.action do |args, options|
    Kontena::Cli::Platform::Api.new.connect
  end
end

command 'login' do |c|
  c.syntax = 'kontena login'
  c.description = 'Login to Kontena.io'
  c.action do |args, options|
    Kontena::Cli::Platform::User.new.login
  end
end

command 'logout' do |c|
  c.syntax = 'kontena logout'
  c.description = 'Logout from Kontena.io'
  c.action do |args, options|
    Kontena::Cli::Platform::User.new.logout
  end
end

command 'grids' do |c|
  c.syntax = 'kontena grids'
  c.description = 'List all grids'
  c.action do |args, options|
    Kontena::Cli::Platform::Grids.new.list
  end
end

command 'use' do |c|
  c.syntax = 'kontena grids GRID_NAME'
  c.description = 'Switch to use specific grid'
  c.action do |args, options|
    raise ArgumentError.new('GRID_NAME is required. For a list of existing grids please run: kontena grids') if args[0].nil?
    Kontena::Cli::Platform::Grids.new.switch_to_grid(args[0])
  end
end

command 'grids create' do |c|
  c.syntax = 'kontena grids create GRID_NAME'
  c.description = 'Create a new grid'
  c.action do |args, options|
    Kontena::Cli::Platform::Grids.new.create(args[0])
  end
end

command 'services' do |c|
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

command 'service create' do |c|
  c.syntax = 'kontena service create <name> <image>'
  c.description = 'Show service details'
  c.option '-p', '--ports Array', Array, 'Exposed ports'
  c.option '-e', '--env Array', Array, 'Environment variables'
  c.option '-c', '--containers INTEGER', Integer, 'Containers count'
  c.option '--stateful', 'Set service as stateful'

  c.action do |args, options|
    Kontena::Cli::Platform::Services.new.create(args[0], args[1], options)
  end
end

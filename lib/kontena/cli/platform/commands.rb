module Kontena::Cli::Platform; end;

require_relative 'user'
require_relative 'api'
require_relative 'grids'

command 'connect' do |c|
  c.syntax = 'kontena connect [URL]'
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

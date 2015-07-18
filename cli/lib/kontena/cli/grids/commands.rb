module Kontena::Cli::Grids; end;

require_relative 'grids'
require_relative 'users'
require_relative 'audit_log'
require_relative 'vpn'
require_relative 'registry'
require_relative 'external_registries'

command 'grid list' do |c|
  c.syntax = 'kontena grid list'
  c.description = 'List all grids'
  c.action do |args, options|
    Kontena::Cli::Grids::Grids.new.list
  end
end

command 'grid use' do |c|
  c.syntax = 'kontena grid use <name>'
  c.description = 'Switch to use specific grid'
  c.action do |args, options|
    raise ArgumentError.new('grid name is required. For a list of existing grids please run: kontena grid list') if args[0].nil?
    Kontena::Cli::Grids::Grids.new.use(args[0])
  end
end

command 'grid show' do |c|
  c.syntax = 'kontena grid show <name>'
  c.description = 'Show grid details'
  c.action do |args, options|
    raise ArgumentError.new('grid name is required. For a list of existing grids please run: kontena grid list') if args[0].nil?
    Kontena::Cli::Grids::Grids.new.show(args[0])
  end
end

command 'grid current' do |c|
  c.syntax = 'kontena grid current'
  c.description = 'Show current grid details'
  c.action do |args, options|
    Kontena::Cli::Grids::Grids.new.current
  end
end

command 'grid audit-log' do |c|
  c.syntax = 'kontena grid audit-log'
  c.description = 'Show audit log of the current grid'
  c.option '-l', '--limit INTEGER', Integer, 'Number of lines'
  c.action do |args, options|
    Kontena::Cli::Grids::AuditLog.new.show(options)
  end
end

command 'grid create' do |c|
  c.syntax = 'kontena grid create <name>'
  c.description = 'Create a new grid'
  c.option '--initial-size INTEGER', Integer, 'Initial number of nodes'
  c.action do |args, options|
    Kontena::Cli::Grids::Grids.new.create(args[0], options)
  end
end

command 'grid remove' do |c|
  c.syntax = 'kontena grid remove <name>'
  c.description = 'Removes grid'
  c.action do |args, options|
    Kontena::Cli::Grids::Grids.new.destroy(args[0])
  end
end

command 'grid list-users' do |c|
  c.syntax = 'kontena grid list-users'
  c.description = 'Show grid users'
  c.action do |args, options|
    Kontena::Cli::Grids::Users.new.list
  end
end

command 'grid add-user' do |c|
  c.syntax = 'kontena grid add-user <email>'
  c.description = 'Assign user to grid'
  c.action do |args, options|
    Kontena::Cli::Grids::Users.new.add(args[0])
  end
end

command 'grid remove-user' do |c|
  c.syntax = 'kontena grid remove-user <email>'
  c.description = 'Unassign user from grid'
  c.action do |args, options|
    Kontena::Cli::Grids::Users.new.remove(args[0])
  end
end


command 'vpn create' do |c|
  c.syntax = 'kontena vpn create'
  c.description = 'Create vpn service'
  c.option '--node STRING', String, 'Node name'
  c.option '--ip STRING', String, 'Node ip'
  c.action do |args, options|
    Kontena::Cli::Grids::Vpn.new.create(options)
  end
end

command 'vpn delete' do |c|
  c.syntax = 'kontena vpn delete'
  c.description = 'Delete vpn service'
  c.action do |args, options|
    Kontena::Cli::Grids::Vpn.new.delete
  end
end

command 'vpn config' do |c|
  c.syntax = 'kontena vpn config'
  c.description = 'Show vpn client config'
  c.action do |args, options|
    Kontena::Cli::Grids::Vpn.new.config
  end
end

command 'registry create' do |c|
  c.syntax = 'kontena registry create'
  c.description = 'Create Docker Registry service'
  c.option '--node STRING', String, 'Node name'
  c.option '--s3-access-key STRING', String, 'S3 access key'
  c.option '--s3-secret-key STRING', String, 'S3 secret key'
  c.option '--s3-bucket STRING', String, 'S3 bucket'
  c.option '--s3-region STRING', String, 'S3 region'
  c.option '--s3-encrypt', 'S3 encrypt data'
  c.option '--s3-secure', 'S3 use secure connection'
  c.option '--azure-account-name STRING', String, 'Azure account name'
  c.option '--azure-account-key STRING', String, 'Azure account key'
  c.option '--azure-container-name STRING', String, 'Azure container name'
  c.action do |args, options|
    Kontena::Cli::Grids::Registry.new.create(options)
  end
end

command 'registry delete' do |c|
  c.syntax = 'kontena registry delete'
  c.description = 'Delete Docker Registry service'
  c.action do |args, options|
    Kontena::Cli::Grids::Registry.new.delete
  end
end

command 'external-registry add' do |c|
  c.syntax = 'kontena external-registry add'
  c.description = 'Add external private registry credentials'
  c.action do |args, options|
    Kontena::Cli::Grids::ExternalRegistries.new.add
  end
end

command 'external-registry list' do |c|
  c.syntax = 'kontena external-registry list'
  c.description = 'List external private registries'
  c.action do |args, options|
    Kontena::Cli::Grids::ExternalRegistries.new.list
  end
end

command 'external-registry delete' do |c|
  c.syntax = 'kontena external-registry delete'
  c.description = 'Delete external private registry'
  c.action do |args, options|
    Kontena::Cli::Grids::ExternalRegistries.new.destroy(args[0])
  end
end

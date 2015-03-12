module Kontena::Cli::Server; end;

require_relative 'server'
require_relative 'user'

command 'connect' do |c|
  c.syntax = 'kontena connect <url>'
  c.description = 'Connect to Kontena server'
  c.action do |args, options|
    Kontena::Cli::Server::Server.new.connect(args[0], options)
  end
end

command 'disconnect' do |c|
  c.syntax = 'kontena disconnect'
  c.description = 'Disconnect from Kontena server'
  c.action do |args, options|
    Kontena::Cli::Server::Server.new.disconnect
  end
end

command 'login' do |c|
  c.syntax = 'kontena login'
  c.description = 'Login to Kontena server'
  c.action do |args, options|
    Kontena::Cli::Server::User.new.login
  end
end

command 'logout' do |c|
  c.syntax = 'kontena logout'
  c.description = 'Logout from Kontena server'
  c.action do |args, options|
    Kontena::Cli::Server::User.new.logout
  end
end

command 'register' do |c|
  c.syntax = 'kontena register'
  c.description = 'Register to Kontena.io'
  c.action do |args, options|
    Kontena::Cli::Server::User.new.register
  end
end

command 'invite' do |c|
  c.syntax = 'kontena invite <email>'
  c.description = 'Invite user to Kontena server'
  c.action do |args, options|
    Kontena::Cli::Server::User.new.invite(args[0])
  end
end

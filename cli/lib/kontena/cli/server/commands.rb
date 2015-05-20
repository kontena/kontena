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

command 'whoami' do |c|
  c.syntax = 'kontena whoami'
  c.description = 'Display your Kontena email address and server url'
  c.action do |args, options|
    Kontena::Cli::Server::User.new.whoami
  end
end

command 'register' do |c|
  c.syntax = 'kontena register'
  c.description = 'Register to Kontena.io'
  c.action do |args, options|
    Kontena::Cli::Server::User.new.register
  end
end

command 'verify account' do |c|
  c.syntax = 'kontena verify account <token>'
  c.description = 'Verify Kontena.io account'
  c.action do |args, options|
    Kontena::Cli::Server::User.new.verify_account(args[0])
  end
end

command 'invite' do |c|
  c.syntax = 'kontena invite <email>'
  c.description = 'Invite user to Kontena server'
  c.action do |args, options|
    Kontena::Cli::Server::User.new.invite(args[0])
  end
end

command 'forgot password' do |c|
  c.syntax = 'kontena forgot password <email>'
  c.description = 'Request password reset for Kontena account'
  c.action do |args, options|
    Kontena::Cli::Server::User.new.request_password_reset(args[0])
  end
end

command 'reset password' do |c|
  c.syntax = 'kontena reset password <token>'
  c.description = 'Reset Kontena password'
  c.action do |args, options|
    Kontena::Cli::Server::User.new.reset_password(args[0])
  end
end

command 'registry add' do |c|
  c.syntax = 'kontena registry add'
  c.description = 'Add registry information'
  c.action do |args, options|
    Kontena::Cli::Server::User.new.add_registry
  end
end

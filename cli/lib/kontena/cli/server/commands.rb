module Kontena::Cli::Server; end;

require_relative 'server'
require_relative 'user'

command 'login' do |c|
  c.syntax = 'kontena login'
  c.description = 'Login to Kontena server'
  c.action do |args, options|
    Kontena::Cli::Server::User.new.login(args[0])
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
  c.option '--bash-completion-path'
  c.action do |args, options|
    Kontena::Cli::Server::User.new.whoami(options)
  end
end

command 'register' do |c|
  c.syntax = 'kontena register'
  c.description = 'Register Kontena account. URL of auth provider can be given optionally.'
  c.action do |args, options|
    Kontena::Cli::Server::User.new.register(args[0], options)
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

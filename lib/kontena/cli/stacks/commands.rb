module Kontena::Cli::Stacks; end;
require_relative 'stacks'

command 'deploy' do |c|
  c.syntax = 'kontena deploy'
  c.description = 'Create service stack'
  c.option '-f', '--file String', 'path to kontena.yml file, default: current directory'
  c.option '-p', '--prefix String', 'prefix of service names, default: name of the current directory'
  c.action do |args, options|
    Kontena::Cli::Stacks::Stacks.new.deploy(options)
  end
end

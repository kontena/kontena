require_relative 'master/vagrant_command'
require_relative 'master/digital_ocean_command'

class Kontena::Cli::MasterCommand < Clamp::Command

  subcommand "vagrant", "Vagrant specific commands", Kontena::Cli::Master::VagrantCommand
  subcommand "digitalocean", "DigitalOcean specific commands", Kontena::Cli::Master::DigitalOceanCommand

  def execute
  end
end

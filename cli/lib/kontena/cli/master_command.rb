require_relative 'master/vagrant_command'

class Kontena::Cli::MasterCommand < Clamp::Command

  subcommand "vagrant", "Vagrant specific commands", Kontena::Cli::Master::VagrantCommand

  def execute
  end
end


module Kontena::Cli::Master

  require_relative 'vagrant/create_command'
  require_relative 'vagrant/start_command'
  require_relative 'vagrant/stop_command'
  require_relative 'vagrant/restart_command'
  require_relative 'vagrant/ssh_command'
  require_relative 'vagrant/terminate_command'

  class VagrantCommand < Clamp::Command

    subcommand "create", "Create a new Vagrant master", Vagrant::CreateCommand
    subcommand "ssh", "SSH into Vagrant master", Vagrant::SshCommand
    subcommand "start", "Start Vagrant master", Vagrant::StartCommand
    subcommand "stop", "Stop Vagrant master", Vagrant::StopCommand
    subcommand "restart", "Restart Vagrant master", Vagrant::RestartCommand
    subcommand "terminate", "Terminate Vagrant master", Vagrant::TerminateCommand

    def execute
    end
  end
end

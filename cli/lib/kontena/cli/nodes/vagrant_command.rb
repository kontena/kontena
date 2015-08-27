require_relative 'vagrant/create_command'
require_relative 'vagrant/start_command'
require_relative 'vagrant/stop_command'
require_relative 'vagrant/restart_command'
require_relative 'vagrant/terminate_command'
require_relative 'vagrant/ssh_command'

module Kontena::Cli::Nodes
  class VagrantCommand < Clamp::Command

    subcommand "create", "Create a new Vagrant node", Vagrant::CreateCommand
    subcommand "ssh", "SSH into Vagrant node", Vagrant::SshCommand
    subcommand "start", "Start Vagrant node", Vagrant::StartCommand
    subcommand "stop", "Stop Vagrant node", Vagrant::StopCommand
    subcommand "restart", "Restart Vagrant node", Vagrant::RestartCommand
    subcommand "terminate", "Terminate Vagrant node", Vagrant::TerminateCommand

    def execute
    end
  end
end

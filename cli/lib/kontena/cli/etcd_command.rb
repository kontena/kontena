require_relative 'etcd/get_command'
require_relative 'etcd/set_command'
require_relative 'etcd/list_command'
require_relative 'etcd/remove_command'

class Kontena::Cli::EtcdCommand < Clamp::Command

  subcommand "get", "Get value", Kontena::Cli::Etcd::GetCommand
  subcommand "set", "Set value", Kontena::Cli::Etcd::SetCommand
  subcommand "ls", "List directory", Kontena::Cli::Etcd::ListCommand
  subcommand "rm", "Remove key or directory", Kontena::Cli::Etcd::RemoveCommand

  def execute
  end
end

require_relative 'etcd/get_command'
require_relative 'etcd/set_command'
require_relative 'etcd/mkdir_command'
require_relative 'etcd/list_command'
require_relative 'etcd/remove_command'

class Kontena::Cli::EtcdCommand < Kontena::Command

  subcommand "get", "Get the current value for a single key", Kontena::Cli::Etcd::GetCommand
  subcommand "set", "Set a value on the specified key", Kontena::Cli::Etcd::SetCommand
  subcommand ["mkdir", "mk"], "Create a directory", Kontena::Cli::Etcd::MkdirCommand
  subcommand ["list", "ls"], "List a directory", Kontena::Cli::Etcd::ListCommand
  subcommand "rm", "Remove a key or a directory", Kontena::Cli::Etcd::RemoveCommand

  def execute
  end
end

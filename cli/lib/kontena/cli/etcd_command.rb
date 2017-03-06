class Kontena::Cli::EtcdCommand < Kontena::Command

  subcommand "get", "Get the current value for a single key", load_subcommand('etcd/get_command')
  subcommand "set", "Set a value on the specified key", load_subcommand('etcd/set_command')
  subcommand ["mkdir", "mk"], "Create a directory", load_subcommand('etcd/mkdir_command')
  subcommand ["list", "ls"], "List a directory", load_subcommand('etcd/list_command')
  subcommand "rm", "Remove a key or a directory", load_subcommand('etcd/remove_command')
  subcommand "health", "Check etcd health", load_subcommand('etcd/health_command')

  def execute
  end
end

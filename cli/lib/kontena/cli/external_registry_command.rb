class Kontena::Cli::ExternalRegistryCommand < Kontena::Command

  subcommand "add", "Add external Docker image registry", load_subcommand('external_registries/add_command')
  subcommand ["list", "ls"], "List external Docker image registries", load_subcommand('external_registries/list_command')
  subcommand ["remove", "rm"], "Remove external Docker image registry", load_subcommand('external_registries/remove_command')

  def execute
  end
end

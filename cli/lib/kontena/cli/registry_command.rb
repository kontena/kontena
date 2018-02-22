class Kontena::Cli::RegistryCommand < Kontena::Command

  subcommand "create", "Create Docker image registry service", load_subcommand('registry/create_command')
  subcommand ["remove","rm"], "Remove Docker image registry service", load_subcommand('registry/remove_command')

  def execute
  end
end

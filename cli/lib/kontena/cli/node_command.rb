class Kontena::Cli::NodeCommand < Kontena::Command

  subcommand ["list","ls"], "List grid nodes", load_subcommand('nodes/list_command')
  subcommand "show", "Show node", load_subcommand('nodes/show_command')
  subcommand "ssh", "Ssh into node", load_subcommand('nodes/ssh_command')
  subcommand "update", "Update node", load_subcommand('nodes/update_command')
  subcommand ["remove","rm"], "Remove node", load_subcommand('nodes/remove_command')
  subcommand "label", "Node label specific commands", load_subcommand('nodes/label_command')
  subcommand "health", "Check node health", load_subcommand('nodes/health_command')

  def execute
  end
end

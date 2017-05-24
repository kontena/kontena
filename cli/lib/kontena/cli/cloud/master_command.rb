module Kontena::Cli::Cloud
  class MasterCommand < Kontena::Command
    subcommand ['list', 'ls'], "List masters in Kontena Cloud", load_subcommand('cloud/master/list_command')
    subcommand "add", "Register a master in Kontena Cloud", load_subcommand('cloud/master/add_command')
    subcommand ['remove', 'rm'], "Remove a master registration from Kontena Cloud", load_subcommand('cloud/master/remove_command')
    subcommand "show", "Show master settings in Kontena Cloud", load_subcommand('cloud/master/show_command')
    subcommand "update", "Update master settings in Kontena Cloud", load_subcommand('cloud/master/update_command')
  end
end

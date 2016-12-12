require_relative 'common'

module Kontena::Cli::Stacks
  class UpgradeCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    banner "Upgrades a stack in a grid on Kontena Master"

    parameter "NAME", "Stack name"
    parameter "[FILE]", "Kontena stack file", default: "kontena.yml"
    option '--deploy', :flag, 'Deploy after upgrade'

    requires_current_master
    requires_current_master_token

    def execute
      require_config_file(file)
      stack = stack_from_yaml(file, name: name)
      spinner "Upgrading stack #{pastel.cyan(name)} " do
        update_stack(stack)
      end
      Kontena.run("stack deploy #{name}") if deploy?
    end

    def update_stack(stack)
      client.put("stacks/#{current_grid}/#{name}", stack)
    end
  end
end

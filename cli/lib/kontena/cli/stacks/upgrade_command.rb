require_relative 'common'

module Kontena::Cli::Stacks
  class UpgradeCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "NAME", "Stack name"
    parameter "FILE", "Kontena stack file"
    option '--deploy', :flag, 'Deploy after upgrade'

    def execute
      require_api_url
      token = require_token
      require_config_file(file)
      stack = stack_from_yaml(file)
      spinner "Upgrading stack #{pastel.cyan(name)} " do
        update_stack(token, stack)
      end
      Kontena.run("stack deploy #{name}")
    end

    def update_stack(token, stack)
      client(token).put("stacks/#{current_grid}/#{name}", stack)
    end
  end
end

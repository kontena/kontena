require_relative 'common'

module Kontena::Cli::Stacks
  class InstallCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "[FILE]", "Kontena stack file", default: "kontena.yml", attribute_name: :filename

    option ['-n', '--name'], 'NAME', 'Define stack name (by default comes from stack file)'
    option '--deploy', :flag, 'Deploy after installation'

    def execute
      require_api_url
      token = require_token
      require_config_file(filename)
      stack = stack_from_yaml(filename)
      stack['name'] = name if name
      spinner "Creating stack #{pastel.cyan(stack['name'])} " do
        create_stack(token, stack)
      end
      Kontena.run("stack deploy #{stack['name']}") if deploy?
    end

    def create_stack(token, stack)
      client(token).post("grids/#{current_grid}/stacks", stack)
    end
  end
end

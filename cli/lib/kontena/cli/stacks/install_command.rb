require_relative 'common'

module Kontena::Cli::Stacks
  class InstallCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    banner "Installs a stack to a grid on Kontena Master"

    parameter "[FILE]", "Kontena stack file or a registry stack name (user/stack or user/stack:version)", default: "kontena.yml", attribute_name: :filename

    option ['-n', '--name'], 'NAME', 'Define stack name (by default comes from stack file)'
    option '--deploy', :flag, 'Deploy after installation'

    requires_current_master
    requires_current_master_token

    def execute

      if !File.exist?(filename) && filename =~ /\A[a-zA-Z0-9\_\.\-]+\/[a-zA-Z0-9\_\.\-]+(?::.*)?\z/
        from_registry = true
      else
        from_registry = false
        require_config_file(filename)
      end

      stack = stack_from_yaml(filename, from_registry: from_registry)
      stack['name'] = name if name
      spinner "Creating stack #{pastel.cyan(stack['name'])} " do
        create_stack(stack)
      end
      Kontena.run("stack deploy #{stack['name']}") if deploy?
    end

    def create_stack(stack)
      client.post("grids/#{current_grid}/stacks", stack)
    end
  end
end

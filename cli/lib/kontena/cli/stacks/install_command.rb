require_relative 'common'

module Kontena::Cli::Stacks
  class InstallCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    banner "Installs a stack to a grid on Kontena Master"

    include Common::StackFileOrNameParam

    include Common::StackNameOption
    option '--[no-]deploy', :flag, 'Trigger deploy after installation', default: true

    include Common::StackValuesFromOption


    requires_current_master
    requires_current_master_token

    def execute
      stack = stack_from_yaml(filename, name: name, values: values)

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

require_relative 'common'
require_relative 'yaml/stack_file_loader'

module Kontena::Cli::Stacks
  class InstallCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    banner "Installs a stack to a grid on Kontena Master"

    include Common::StackFileOrNameParam

    include Common::StackNameOption
    option '--[no-]deploy', :flag, 'Trigger deploy after installation', default: true

    include Common::StackValuesToOption
    include Common::StackValuesFromOption

    option '--parent-name', '[PARENT_NAME]', "Set parent stack name", hidden: true
    option '--skip-dependencies', :flag, "Do not install any stack dependencies"

    requires_current_master
    requires_current_master_token

    def execute
      set_env_variables(stack_name, current_grid)

      install_dependencies unless skip_dependencies?

      stack # runs validations

      hint_on_validation_notifications(reader.notifications)
      abort_on_validation_errors(reader.errors)

      dump_variables if values_to

      create_stack
      deploy_stack if deploy?
    end

    def install_dependencies
      dependencies = loader.dependencies
      return if dependencies.nil?
      dependencies.each do |dependency|
        target_name = "#{stack_name}-#{dependency['name']}"
        caret "Installing dependency #{pastel.cyan(dependency['stack'])} as #{pastel.cyan(target_name)}"
        cmd = ['stack', 'install', '-n', target_name, '--parent-name', stack_name]

        dependency['variables'].merge(dependency_values_from_options(dependency['name'])).each do |key, value|
          cmd.concat ['-v', "#{key}=#{value}"]
        end

        cmd << '--no-deploy' unless deploy?

        cmd << dependency['stack']
        Kontena.run!(cmd)
      end
    end

    def create_stack
      spinner "Creating stack #{pastel.cyan(stack['name'])} " do
        client.post("grids/#{current_grid}/stacks", stack)
      end
    end

    def deploy_stack
      Kontena.run!(['stack', 'deploy', stack['name']])
    end
  end
end

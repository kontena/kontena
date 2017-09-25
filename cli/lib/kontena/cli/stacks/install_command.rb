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
    option '--dry-run', :flag, "Simulate install"

    requires_current_master
    requires_current_master_token

    # @return [Hash] yaml reader execute result hash
    def execute
      set_env_variables(stack_name, current_grid)

      unless skip_dependencies?
        values_from_dependencies = install_dependencies
        values_from_installed_stacks.merge!(values_from_dependencies)
      end

      stack # runs validations

      hint_on_validation_notifications(reader.notifications)
      abort_on_validation_errors(reader.errors)

      dump_variables if values_to

      create_stack

      deploy_stack if deploy?

      stack
    end

    # @return [Hash{String => Hash}] A hash of hashes, first level key is dependent stack name, second level is variable name.
    def install_dependencies
      dependencies = loader.dependencies
      result = {}
      return result if dependencies.nil?
      dependencies.each do |dependency|
        target_name = "#{stack_name}-#{dependency['name']}"
        caret "Installing dependency #{pastel.cyan(dependency[:stack])} as #{pastel.cyan(target_name)}"
        cmd = ['stack', 'install', '-n', target_name, '--parent-name', stack_name]

        dependency['variables'].merge(dependency_values_from_options(dependency['name'])).each do |key, value|
          cmd.concat ['-v', "#{key}=#{value}"]
        end

        cmd << '--dry-run' if dry_run?

        cmd << '--no-deploy' unless deploy?

        cmd << dependency['stack']
        dependency_result = Kontena.run!(cmd)
        dependency_result_variables = dependency_result['variables'] || {}
        dependency_result_variables.each do |key, value|
          result[dependency['name'] + '.' + key] = value
        end
      end
      result
    end

    def create_stack
      return if dry_run?
      spinner "Creating stack #{pastel.cyan(stack['name'])} " do
        client.post("grids/#{current_grid}/stacks", stack)
      end
    end

    def deploy_stack
      if dry_run?
        caret "Stack #{stack['name']} deploy would be triggered", dots: false
      else
        Kontena.run!(['stack', 'deploy', stack['name']])
      end
    end
  end
end

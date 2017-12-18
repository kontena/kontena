require_relative 'common'
require 'yaml'

module Kontena::Cli::Stacks
  class ValidateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    banner "Validates a YAML file"

    include Common::StackFileOrNameParam
    include Common::StackNameOption

    include Common::StackValuesToOption
    include Common::StackValuesFromOption
    include Common::NoPromptOption

    option '--online', :flag, "Enable connections to current master", default: false
    option '--dependency-tree', :flag, "Show dependency tree"
    option '--[no-]dependencies', :flag, "Validate dependencies", default: true
    option '--parent-name', '[PARENT_NAME]', "Set parent name", hidden: true
    option '--format', 'yaml|api-json', "Output Format", default: 'yaml'

    def validate_dependencies
      dependencies = loader.dependencies
      return if dependencies.nil?
      dependencies.each do |dependency|
        target_name = "#{stack_name}-#{dependency['name']}"
        cmd = ['stack', 'validate']
        cmd << '--online' if online?
        cmd.concat ['--parent-name', stack_name]

        dependency['variables'].merge(dependency_values_from_options(dependency['name'])).each do |key, value|
          cmd.concat ['-v', "#{key}=#{value}"]
        end
        cmd << dependency['stack']
        Kontena.run(cmd)
      end
    end

    def execute
      if online?
        set_env_variables(stack_name, require_current_grid)
      else
        config.current_master = nil
        set_env_variables(stack_name, 'validate', 'validate-platform')
      end

      if dependency_tree?
        puts ::YAML.dump('name' => stack_name, 'stack' => source, 'depends' => stack['dependencies'])
        exit 0
      end

      validate_dependencies if dependencies?

      stack # runs validations

      hint_on_validation_notifications(reader.notifications, dependencies? ? loader.source : nil)
      abort_on_validation_errors(reader.errors, dependencies? ? loader.source : nil)

      dump_variables if values_to

      case self.format
      when 'api-json'
        puts JSON.pretty_generate(stack)
      when 'yaml'
        result = ::YAML.dump(reader.fully_interpolated_yaml)
        result = result.sub(/\A---$/, "---\n# #{loader.source}") if dependencies?
        puts result
      else
        exit_with_error "Unknown --format=#{self.format}"
      end
    end
  end
end

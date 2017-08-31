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

    option '--online', :flag, "Enable connections to current master", default: false
    option '--dependency-tree', :flag, "Show dependency tree"
    option '--[no-]dependencies', :flag, "Validate dependencies", default: true

    def validate_dependencies
      dependencies = loader.dependencies
      return if dependencies.nil?
      dependencies.each do |dependency|
        target_name = "#{stack_name}-#{dependency[:name]}"
        cmd = ['stack', 'validate']
        cmd << '--online' if online?

        dependency[:variables].merge(dependency_values_from_options(dependency[:name])).each do |key, value|
          cmd.concat ['-v', "#{key}=#{value}"]
        end
        cmd << dependency[:stack]
        Kontena.run(cmd)
      end
    end

    def execute
      unless online?
        config.current_master = nil
        set_env_variables(stack_name, 'validate', 'validate-platform')
      end

      if dependency_tree?
        puts ::YAML.dump({'name' => stack_name, 'stack' => source, 'depends' => JSON.parse(stack[:dependencies].to_json)})
        exit 0
      end

      validate_dependencies if dependencies?

      hint_on_validation_notifications(stack[:notifications], dependencies? ? loader.source : nil) unless stack[:notifications].empty?
      abort_on_validation_errors(stack[:errors], dependencies? ? loader.source : nil) unless stack[:errors].empty?

      dump_variables if values_to

      result = reader.fully_interpolated_yaml.merge(
        # simplest way to stringify keys in a hash
        'variables' => JSON.parse(reader.variables.to_h(with_values: true, with_errors: true).to_json)
      )
      if dependencies?
        puts ::YAML.dump(result).sub(/\A---$/, "---\n# #{loader.source} :")
      else
        puts ::YAML.dump(result)
      end
    end
  end
end


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
    option '--dependencies', :flag, "Show dependency tree"

    def execute
      unless online?
        config.current_master = nil
        set_env_variables(stack_name, 'validate', 'validate-platform')
      end

      if dependencies?
        puts ::YAML.dump(JSON.parse(stack[:dependencies].to_json))
        exit 0
      end

      hint_on_validation_notifications(stack[:notifications]) unless stack[:notifications].empty?
      abort_on_validation_errors(stack[:errors]) unless stack[:errors].empty?

      dump_variables if values_to

      result = reader.fully_interpolated_yaml.merge(
        # simplest way to stringify keys in a hash
        'variables' => JSON.parse(reader.variables.to_h(with_values: true, with_errors: true).to_json)
      )
      puts ::YAML.dump(result)
    end
  end
end


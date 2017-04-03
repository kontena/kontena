require_relative 'common'

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

    requires_current_master # the stack may use a vault resolver
    requires_current_master_token

    def execute
      reader = reader_from_yaml(filename, name: name, values: values)
      outcome = reader.execute
      hint_on_validation_notifications(outcome[:notifications]) if outcome[:notifications].size > 0
      abort_on_validation_errors(outcome[:errors]) if outcome[:errors].size > 0

      dump_variables(reader) if values_to

      result = reader.fully_interpolated_yaml.merge(
        # simplest way to stringify keys in a hash
        'variables' => JSON.parse(reader.variables.to_h(with_values: true, with_errors: true).to_json)
      )
      puts ::YAML.dump(result)
    end
  end
end


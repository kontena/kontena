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

    option '--online', :flag, "Enable connections to current master", default: false

    def execute
      unless online?
        config.current_master = nil
        values ||= {}
        values.merge!('GRID' => 'validate')
      end

      reader = reader_from_yaml(filename, name: name, values: values)
      outcome = reader.execute
      hint_on_validation_notifications(outcome[:notifications]) unless outcome[:notifications].empty?
      abort_on_validation_errors(outcome[:errors]) unless outcome[:errors].empty?

      dump_variables(reader) if values_to

      result = reader.fully_interpolated_yaml.merge(
        # simplest way to stringify keys in a hash
        'variables' => JSON.parse(reader.variables.to_h(with_values: true, with_errors: true).to_json)
      )
      puts ::YAML.dump(result)
    end
  end
end


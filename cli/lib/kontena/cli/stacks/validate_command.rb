require_relative 'common'

module Kontena::Cli::Stacks
  class ValidateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    banner "Validates a YAML file"

    include Common::StackFileOrNameParam
    include Common::StackNameOption

    option '--values-to', '[FILE]', 'Output variable values as YAML to file'

    include Common::StackValuesFromOption

    requires_current_master # the stack may use a vault resolver
    requires_current_master_token

    def execute

      if !File.exist?(filename) && filename =~ /\A[a-zA-Z0-9\_\.\-]+\/[a-zA-Z0-9\_\.\-]+(?::.*)?\z/
        from_registry = true
      else
        from_registry = false
        require_config_file(filename)
      end

      reader = reader_from_yaml(filename, from_registry: from_registry, name: name, values: values)
      outcome = reader.execute
      hint_on_validation_notifications(outcome[:notifications]) if outcome[:notifications].size > 0
      abort_on_validation_errors(outcome[:errors]) if outcome[:errors].size > 0

      if values_to
        vals = reader.variables.to_h(values_only: true).reject {|k,_| k == 'STACK' || k == 'GRID' }
        File.write(values_to, ::YAML.dump(vals))
      end
      result = reader.fully_interpolated_yaml.merge(
        # simplest way to stringify keys in a hash
        'variables' => JSON.parse(reader.variables.to_h(with_values: true, with_errors: true).to_json)
      )
      puts ::YAML.dump(result)
    end
  end
end


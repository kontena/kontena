module Kontena
  module Cli
    module Stacks
      module YAML
        autoload :Opto, 'kontena/cli/stacks/yaml/opto'
        autoload :Reader, 'kontena/cli/stacks/yaml/reader'
        autoload :CustomValidators, 'kontena/cli/stacks/yaml/custom_validators'
        autoload :Validations, 'kontena/cli/stacks/yaml/validations'
      end
    end
  end
end

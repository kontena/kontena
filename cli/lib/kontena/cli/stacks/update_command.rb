require_relative 'common'

module Kontena::Cli::Stacks
  class UpdateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "NAME", "Stack name"

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena stack file', attribute_name: :filename, default: 'kontena.yml'

    def execute
      require_api_url
      token = require_token
      require_config_file(filename)
      stack = stack_from_yaml(filename)
      spinner "Updating stack #{name} " do
        update_stack(token, stack)
      end
    end

    def update_stack(token, stack)
      client(token).put("stacks/#{current_grid}/#{name}", stack)
    end
  end
end

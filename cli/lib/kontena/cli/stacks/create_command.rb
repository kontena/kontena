require_relative 'common'

module Kontena::Cli::Stacks
  class CreateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena stack file', attribute_name: :filename, default: 'kontena.yml'
    option ['-n', '--name'], 'NAME', 'Define stack name (by default comes from stack file)'

    def execute
      require_api_url
      token = require_token
      require_config_file(filename)
      stack = stack_from_yaml(filename)
      stack['name'] = name if name
      spinner "Creating stack #{pastel.cyan(name)} " do
        create_stack(token, stack)
      end
    end

    def create_stack(token, stack)
      client(token).post("grids/#{current_grid}/stacks", stack)
    end
  end
end

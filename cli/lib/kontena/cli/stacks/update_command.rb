require_relative 'common'

module Kontena::Cli::Stacks
  class UpdateCommand < Kontena::Command
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
      update_stack(token, stack)
    end

    def update_stack(token, stack)
      client(token).put("stacks/#{current_grid}/#{stack['name']}", stack)
    end
  end
end

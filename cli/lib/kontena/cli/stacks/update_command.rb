require_relative 'common'

module Kontena::Cli::Stacks
  class UpdateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena stack file', attribute_name: :filename, default: 'kontena.yml'

    def execute
      require_api_url
      require_token
      require_config_file(filename)
      @stack = stack_from_yaml(filename)

      update_stack
    end

    private

    def update_stack
      client(token).put("stacks/#{current_grid}/#{@stack['name']}", @stack)
    end

  end
end

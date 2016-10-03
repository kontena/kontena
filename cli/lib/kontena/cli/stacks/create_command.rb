require_relative 'common'

module Kontena::Cli::Stacks
  class CreateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    option ['-f', '--file'], 'FILE', 'Specify an alternate Kontena stack file', attribute_name: :filename, default: 'kontena.yml'

    def execute
      require_api_url
      require_token
      require_config_file(filename)
      @stack = stack_from_yaml(filename)

      create_stack
    end

    private

    def create_stack
      client(token).post("stacks/#{current_grid}", @stack)
    end

  end
end

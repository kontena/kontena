require_relative 'common'

module Kontena::Cli::Stacks
  class DeployCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "NAME", "Stack name"

    def execute
      require_api_url
      require_token

      deploy_stack(name)
    end

    private


    def deploy_stack
      client(token).post("stacks/#{current_grid}/#{name}/deploy", {})
    end

  end
end

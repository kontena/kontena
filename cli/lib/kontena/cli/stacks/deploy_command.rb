require_relative 'common'

module Kontena::Cli::Stacks
  class DeployCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "NAME", "Stack name"

    def execute
      require_api_url
      token = require_token

      spinner "Deploying stack #{name}" do
        deploy_stack(token, name)
      end
    end

    def deploy_stack(token, name)
      client(token).post("stacks/#{current_grid}/#{name}/deploy", {})
    end
  end
end

require_relative 'common'

module Kontena::Cli::Stacks
  class DeployCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions
    include Common

    parameter "NAME", "Stack name"

    requires_current_master_token

    def execute
      deploy_stack(name)
    end

    private


    def deploy_stack
      client.post("stacks/#{current_grid}/#{name}/deploy", {})
    end

  end
end

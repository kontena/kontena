module Kontena::Cli::Stacks
  class InspectCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    banner "Inspect a stack"

    parameter "NAME", "Stack name"

    requires_current_master
    requires_current_master_token

    def execute
      puts client.get("stacks/#{current_grid}/#{name}")['source']
    end
  end
end

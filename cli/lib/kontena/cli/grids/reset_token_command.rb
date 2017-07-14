module Kontena::Cli::Grids
  class ResetTokenCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::GridOptions

    requires_current_master
    requires_current_master_token
    requires_current_grid

    parameter "[GRID]", "Grid name"

    option "--force", :flag, "Force token update"

    def execute
      confirm("Resetting the grid weave secrets will temporarily disrupt the overlay network, and cause transient service errors. Are you sure?")

      data = {}

      spinner "Resetting grid #{current_grid.colorize(:cyan)} token" do
        client.post("grids/#{current_grid}/token", data)
      end
    end
  end
end

require_relative 'common'
require "kontena/cli/helpers/health_helper"

module Kontena::Cli::Grids
  class HealthCommand < Kontena::Command
    include Kontena::Cli::Common
    include Kontena::Cli::Helpers::HealthHelper
    include Common

    parameter "[NAME]", "Grid name"

    def execute
      require_api_url

      grid = get_grid(name)
      grid_nodes = client(require_token).get("grids/#{grid['name']}/nodes")

      return show_grid_health(grid, grid_nodes['nodes'])
    end
  end
end

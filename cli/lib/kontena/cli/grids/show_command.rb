require_relative 'common'

module Kontena::Cli::Grids
  class ShowCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    parameter "NAME", "Grid name"

    def execute
      require_api_url

      grid = find_grid_by_name(name)
      abort("Grid not found".colorize(:red)) unless grid
      
      print_grid(grid)
    end
  end
end

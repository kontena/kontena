require_relative 'common'

module Kontena::Cli::Grids
  class ShowCommand < Kontena::Command
    include Common

    parameter "NAME", "Grid name"

    option '--token', :flag, 'Just output grid token'

    def execute
      require_api_url

      grid = find_grid_by_name(name)
      exit_with_error("Grid not found") unless grid

      if self.token?
        puts grid['token']
      else
        print_grid(grid)
      end
    end
  end
end

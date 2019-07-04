require_relative 'common'

module Kontena::Cli::Grids
  class ShowCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    parameter "NAME", "Grid name"

    option '--token', :flag, 'Just output grid token'

    def execute
      require_api_url

      if self.token?
        token = get_grid_token(name)
        exit_with_error("Grid not found") unless token
        puts token['token']
      else
        grid = find_grid_by_name(name)
        exit_with_error("Grid not found") unless grid
        print_grid(grid)
      end
    end
  end
end

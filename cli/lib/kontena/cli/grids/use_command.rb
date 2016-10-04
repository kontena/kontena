require_relative 'common'

module Kontena::Cli::Grids
  class UseCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    parameter "NAME", "Grid name to use"

    def execute
      require_api_url
      grid = find_grid_by_name(name)
      if !grid.nil?
        self.current_grid = grid
        puts "Using grid: #{grid['name'].cyan}"
      else
        abort "Could not resolve grid by name [#{name}]. For a list of existing grids please run: kontena grid list".colorize(:red)
      end
    end
  end
end

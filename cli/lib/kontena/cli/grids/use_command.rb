require_relative 'common'

module Kontena::Cli::Grids
  class UseCommand < Kontena::Command
    include Common

    requires_current_master

    parameter "NAME", "Grid name to use"

    option ['--silent'], :flag, 'Reduce output verbosity'

    def execute
      grid = find_grid_by_name(name)
      unless grid
        exit_with_error "Could not resolve grid by name [#{name}]. For a list of existing grids please run: kontena grid list".colorize(:red)
      end
      config.current_master.grid = grid['name']
      config.write
      unless self.silent?
        puts "Using grid: #{pastel.cyan(grid['name'])}"
      end
    end
  end
end

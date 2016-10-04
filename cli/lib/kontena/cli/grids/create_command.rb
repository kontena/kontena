require_relative 'common'

module Kontena::Cli::Grids
  class CreateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    parameter "NAME", "Grid name"
    option "--initial-size", "INITIAL_SIZE", "Initial grid size (number of nodes)", default: 1

    def execute
      require_api_url

      token = require_token
      payload = {
        name: name
      }
      payload[:initial_size] = initial_size if initial_size
      grid = client(token).post('grids', payload)
      if grid
        self.current_grid = grid
        puts "Using grid: #{grid['name'].cyan}"
      end
    end
  end
end

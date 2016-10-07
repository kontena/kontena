require_relative 'common'

module Kontena::Cli::Grids
  class CreateCommand < Kontena::Command
    include Kontena::Cli::Common
    include Common

    parameter "NAME", "Grid name"

    option "--initial-size", "INITIAL_SIZE", "Initial grid size (number of nodes)", default: 1
    option "--silent", :flag, "Reduce output verbosity"
    option "--token", "[TOKEN]", "Set grid token"

    def execute
      require_api_url

      token = require_token
      payload = {
        name: name
      }
      payload[:token] = token if token
      payload[:initial_size] = initial_size if initial_size
      grid = nil
      if initial_size == 1
        warning "Option --initial-size=1 is only recommended for test/dev usage" unless running_silent?
      end
      spinner "Creating #{pastel.cyan(name)} grid " do
        grid = client(token).post('grids', payload)
      end
      if grid
        spinner "Switching scope to #{pastel.cyan(name)} grid " do
          config.current_grid = grid['name']
          config.write
        end
      end
    end
  end
end

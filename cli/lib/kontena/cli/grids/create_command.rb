require_relative 'common'

module Kontena::Cli::Grids
  class CreateCommand < Kontena::Command
    include Common

    parameter "NAME", "Grid name"

    option "--initial-size", "INITIAL_SIZE", "Initial grid size (number of nodes)", default: 1
    option "--silent", :flag, "Reduce output verbosity"
    option "--token", "[TOKEN]", "Set grid token"
    option "--subnet", "[CIDR]", "Configure grid overlay subnet"
    option "--supernet", "[CIDR]", "Configure grid IPAM supernet"

    include Common::Parameters

    requires_current_master_token

    def execute
      validate_grid_parameters

      if initial_size == 1
        warning "Option --initial-size=1 is only recommended for test/dev usage" unless running_silent?
      end

      payload = {
        name: name
      }
      payload[:token] = self.token if self.token
      payload[:initial_size] = self.initial_size if self.initial_size
      payload[:subnet] = subnet if subnet
      payload[:supernet] = supernet if supernet

      build_grid_parameters(payload)

      grid = spinner "Creating #{pastel.cyan(name)} grid " do
        client.post('grids', payload)
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

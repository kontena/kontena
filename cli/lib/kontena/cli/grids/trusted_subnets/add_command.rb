module Kontena::Cli::Grids::TrustedSubnets
  class AddCommand < Kontena::Command
    include Kontena::Cli::Common

    parameter "SUBNET", "Trusted subnet"
    parameter "[NAME]", "Grid name (default: current grid)"

    def execute
      require_api_url
      token = require_token
      grid_name = name || current_grid
      grid = client(token).get("grids/#{grid_name}")
      data = {trusted_subnets: grid['trusted_subnets'] + [self.subnet]}
      spinner "Adding #{subnet.colorize(:cyan)} as a trusted subnet to #{grid_name.colorize(:cyan)} grid " do
        client(token).put("grids/#{grid_name}", data)
      end
    end
  end
end
